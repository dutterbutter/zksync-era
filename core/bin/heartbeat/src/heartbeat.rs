use std::time::Duration;

use async_trait::async_trait;
use tokio::{select, time};
use tracing::info;

use zksync_node_framework::{
    task::{Task, TaskId},
    wiring_layer::{WiringLayer, WiringError},
    IntoContext, StopReceiver,
};

pub struct HeartbeatTask;

#[async_trait]
impl Task for HeartbeatTask {
    fn id(&self) -> TaskId {
        "heartbeat_task".into()
    }

    async fn run(self: Box<Self>, mut stop: StopReceiver) -> anyhow::Result<()> {
        let mut ticker = time::interval(Duration::from_secs(1));

        loop {
            select! {
                _ = ticker.tick() => info!("💓 node is alive"),
                _ = stop.0.changed() => {
                    info!("HeartbeatTask shutting down");
                    return Ok(())
                }
            }
        }
    }
}

#[derive(IntoContext)]
pub struct HeartbeatOutput {
    #[context(task)]
    task: HeartbeatTask,
}

#[derive(Debug)]
pub struct HeartbeatLayer;

#[async_trait]
impl WiringLayer for HeartbeatLayer {
    type Input = ();
    type Output = HeartbeatOutput;

    fn layer_name(&self) -> &'static str {
        "heartbeat_layer"
    }

    async fn wire(self, _input: Self::Input) -> Result<Self::Output, WiringError> {
        Ok(HeartbeatOutput { task: HeartbeatTask })
    }
}