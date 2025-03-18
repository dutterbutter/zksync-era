use anyhow::Context;
use zksync_config::configs::contracts::{
    chain::L2Contracts, ecosystem::L1SpecificContracts, SettlementLayerSpecificContracts,
};
use zksync_consistency_checker::get_db_settlement_mode;
use zksync_contracts::getters_facet_contract;
use zksync_contracts_loader::{get_settlement_layer_from_l1, load_settlement_layer_contracts};
use zksync_eth_client::EthInterface;
use zksync_types::{
    settlement::SettlementMode, url::SensitiveUrl, Address, L2ChainId, L2_BRIDGEHUB_ADDRESS,
};
use zksync_web3_decl::client::Client;

use crate::{
    implementations::resources::{
        contracts::{
            L1ChainContractsResource, L1EcosystemContractsResource, L2ContractsResource,
            SettlementLayerContractsResource,
        },
        eth_interface::{EthInterfaceResource, L2InterfaceResource},
        pools::{MasterPool, PoolResource},
        settlement_layer::{SettlementModeResource, SlChainIdResource},
    },
    wiring_layer::{WiringError, WiringLayer},
    FromContext, IntoContext,
};

/// Wiring layer for [`SettlementLayerData`].
#[derive(Debug)]
pub struct SettlementLayerDataEn {
    l1_specific_contracts: L1SpecificContracts,
    l1_chain_contracts: SettlementLayerSpecificContracts,
    l2_contracts: L2Contracts,
    chain_id: L2ChainId,
    gateway_rpc_url: Option<SensitiveUrl>,
}

impl SettlementLayerDataEn {
    pub fn new(
        chain_id: L2ChainId,
        l1_specific_contracts: L1SpecificContracts,
        l1_chain_contracts: SettlementLayerSpecificContracts,
        l2_contracts: L2Contracts,
        gateway_rpc_url: Option<SensitiveUrl>,
    ) -> Self {
        Self {
            l1_specific_contracts,
            l1_chain_contracts,
            l2_contracts,
            chain_id,
            gateway_rpc_url,
        }
    }
}

#[derive(Debug, FromContext)]
#[context(crate = crate)]
pub struct Input {
    pub eth_client: EthInterfaceResource,
    pub master_pool: PoolResource<MasterPool>,
}

#[derive(Debug, IntoContext)]
#[context(crate = crate)]
pub struct Output {
    initial_settlement_mode: SettlementModeResource,
    contracts: SettlementLayerContractsResource,
    l1_contracts: L1ChainContractsResource,
    l1_ecosystem_contracts: L1EcosystemContractsResource,
    sl_chain_id_resource: SlChainIdResource,
    l2_contracts: L2ContractsResource,
}

#[async_trait::async_trait]
impl WiringLayer for SettlementLayerDataEn {
    type Input = Input;
    type Output = Output;

    fn layer_name(&self) -> &'static str {
        "settlement_layer_en"
    }

    async fn wire(self, input: Self::Input) -> Result<Self::Output, WiringError> {
        let chain_id = input.eth_client.0.fetch_chain_id().await.unwrap();

        let initial_db_sl_mode =
            get_db_settlement_mode(input.master_pool.get().await?, chain_id).await?;

        let (initial_sl_mode, chain_id) = if let Some(mode) = initial_db_sl_mode {
            (mode, chain_id)
        } else {
            // If it's the new chain it's safe to check the actual sl onchain,
            // in the worst case scenario chain
            // en will be restarted right after the first batch and fill the database with correct values
            get_settlement_layer_from_l1(
                &input.eth_client.0.as_ref(),
                self.l1_chain_contracts
                    .chain_contracts_config
                    .diamond_proxy_addr,
                &getters_facet_contract(),
            )
            .await?
        };

        let l2_eth_client = self
            .gateway_rpc_url
            .map(|url| Client::http(url).context("Client::new()"))
            .transpose()?
            .map(|mut builder| {
                if initial_sl_mode.is_gateway() {
                    builder = builder.for_network(L2ChainId::new(chain_id.0).unwrap().into());
                }
                L2InterfaceResource(Box::new(builder.build()))
            });

        let (client, bridgehub): (Box<dyn EthInterface>, Address) = match initial_sl_mode {
            SettlementMode::SettlesToL1 => (
                Box::new(input.eth_client.0),
                self.l1_chain_contracts
                    .ecosystem_contracts
                    .bridgehub_proxy_addr
                    .unwrap(),
            ),
            SettlementMode::Gateway => (Box::new(l2_eth_client.unwrap().0), L2_BRIDGEHUB_ADDRESS),
        };

        // There is no need to specify multicall3 for external node
        let contracts =
            load_settlement_layer_contracts(client.as_ref(), bridgehub, self.chain_id, None)
                .await?;
        let contracts = match contracts {
            Some(contracts) => contracts,
            None => match initial_sl_mode {
                SettlementMode::SettlesToL1 => self.l1_chain_contracts.clone(),
                SettlementMode::Gateway => {
                    return Err(anyhow::anyhow!("No contacts deployed to contracts"))?
                }
            },
        };

        Ok(Output {
            contracts: SettlementLayerContractsResource(contracts),
            l1_contracts: L1ChainContractsResource(self.l1_chain_contracts),
            l1_ecosystem_contracts: L1EcosystemContractsResource(self.l1_specific_contracts),
            l2_contracts: L2ContractsResource(self.l2_contracts),
            initial_settlement_mode: SettlementModeResource(initial_sl_mode),
            sl_chain_id_resource: SlChainIdResource(chain_id),
        })
    }
}
