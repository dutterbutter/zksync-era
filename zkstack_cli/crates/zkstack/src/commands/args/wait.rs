use std::{fmt, future::Future, time::Duration};

use anyhow::Context as _;
use clap::Parser;
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};
use serde_json;
use tokio::time::MissedTickBehavior;
use zkstack_cli_common::logger;

use crate::messages::{
    msg_wait_non_successful_response, msg_wait_not_healthy, msg_wait_starting_polling,
    msg_wait_timeout, MSG_WAIT_POLL_INTERVAL_HELP, MSG_WAIT_TIMEOUT_HELP,
};

#[derive(Debug, Clone, Copy)]
enum PolledComponent {
    Prometheus,
    HealthCheck,
    ChainId,
}

impl fmt::Display for PolledComponent {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::Prometheus => "Prometheus",
            Self::HealthCheck => "health check",
            Self::ChainId => "chain ID",
        })
    }
}

#[derive(Debug, Parser, Serialize, Deserialize)]
pub struct WaitArgs {
    #[arg(long, short = 't', value_name = "SECONDS", help = MSG_WAIT_TIMEOUT_HELP)]
    timeout: Option<u64>,
    #[arg(long, value_name = "MILLIS", help = MSG_WAIT_POLL_INTERVAL_HELP, default_value_t = 100)]
    poll_interval: u64,
}

impl WaitArgs {
    pub fn poll_interval(&self) -> Duration {
        Duration::from_millis(self.poll_interval)
    }

    pub async fn poll_prometheus(&self, port: u16, verbose: bool) -> anyhow::Result<()> {
        let component = PolledComponent::Prometheus;
        let url = format!("http://127.0.0.1:{port}/metrics");
        self.poll_with_timeout(component, self.poll_inner(component, &url, verbose))
            .await
    }

    pub async fn poll_health_check(&self, url: &str, verbose: bool) -> anyhow::Result<()> {
        let component = PolledComponent::HealthCheck;
        self.poll_with_timeout(component, self.poll_inner(component, url, verbose))
            .await
    }

    pub async fn poll_chain_id(&self, url: &str, verbose: bool) -> anyhow::Result<()> {
        let component = PolledComponent::ChainId;
        self.poll_with_timeout(component, self.poll_chain_id_inner(url, verbose))
            .await
    }

    pub async fn poll_with_timeout(
        &self,
        component: impl fmt::Display,
        action: impl Future<Output = anyhow::Result<()>>,
    ) -> anyhow::Result<()> {
        match self.timeout {
            None => action.await,
            Some(timeout) => tokio::time::timeout(Duration::from_secs(timeout), action)
                .await
                .map_err(|_| anyhow::Error::msg(msg_wait_timeout(&component)))?,
        }
    }

    async fn poll_inner(
        &self,
        component: PolledComponent,
        url: &str,
        verbose: bool,
    ) -> anyhow::Result<()> {
        let poll_interval = Duration::from_millis(self.poll_interval);
        let mut interval = tokio::time::interval(poll_interval);
        interval.set_missed_tick_behavior(MissedTickBehavior::Skip);

        if verbose {
            logger::debug(msg_wait_starting_polling(&component, url, poll_interval));
        }

        let client = reqwest::Client::builder()
            .connect_timeout(poll_interval)
            .build()
            .context("failed to build reqwest::Client")?;

        loop {
            interval.tick().await;

            let response = match client.get(url).send().await {
                Ok(response) => response,
                Err(_) => {
                    continue;
                }
            };

            match component {
                PolledComponent::Prometheus => {
                    response
                        .error_for_status()
                        .with_context(|| msg_wait_non_successful_response(&component))?;
                    return Ok(());
                }
                PolledComponent::HealthCheck => {
                    if response.status().is_success() {
                        // Parse response as JSON and check status field
                        let json: serde_json::Value = response.json().await.with_context(|| {
                            format!("failed to parse JSON response from {}", url)
                        })?;

                        if let Some(status) = json.get("status") {
                            if status.as_str() == Some("ready") {
                                return Ok(());
                            }
                        }

                        if verbose {
                            logger::debug(msg_wait_not_healthy(url));
                        }
                    } else if response.status() == StatusCode::SERVICE_UNAVAILABLE {
                        if verbose {
                            logger::debug(msg_wait_not_healthy(url));
                        }
                    } else {
                        response
                            .error_for_status()
                            .with_context(|| msg_wait_non_successful_response(&component))?;
                    }
                }
                PolledComponent::ChainId => {
                    // This case should never be reached since ChainId uses poll_chain_id_inner
                    unreachable!("ChainId polling should use poll_chain_id_inner method")
                }
            }
        }
    }

    async fn poll_chain_id_inner(&self, url: &str, verbose: bool) -> anyhow::Result<()> {
        let poll_interval = Duration::from_millis(self.poll_interval);
        let mut interval = tokio::time::interval(poll_interval);
        interval.set_missed_tick_behavior(MissedTickBehavior::Skip);

        if verbose {
            logger::debug(msg_wait_starting_polling(&PolledComponent::ChainId, url, poll_interval));
        }

        let client = reqwest::Client::builder()
            .connect_timeout(poll_interval)
            .build()
            .context("failed to build reqwest::Client")?;

        let json_rpc_payload = serde_json::json!({
            "jsonrpc": "2.0",
            "method": "eth_chainId",
            "params": [],
            "id": 1
        });

        loop {
            interval.tick().await;

            let response = match client
                .post(url)
                .json(&json_rpc_payload)
                .send()
                .await
            {
                Ok(response) => response,
                Err(_) => {
                    continue;
                }
            };

            if response.status().is_success() {
                // Parse response as JSON-RPC response and check for valid result
                let json: serde_json::Value = response.json().await.with_context(|| {
                    format!("failed to parse JSON-RPC response from {}", url)
                })?;

                // Check if it's a valid JSON-RPC response with a result
                if let Some(result) = json.get("result") {
                    if !result.is_null() {
                        return Ok(());
                    }
                }

                if verbose {
                    logger::debug(msg_wait_not_healthy(url));
                }
            } else if response.status() == StatusCode::SERVICE_UNAVAILABLE {
                if verbose {
                    logger::debug(msg_wait_not_healthy(url));
                }
            } else {
                response
                    .error_for_status()
                    .with_context(|| msg_wait_non_successful_response(&PolledComponent::ChainId))?;
            }
        }
    }
}
