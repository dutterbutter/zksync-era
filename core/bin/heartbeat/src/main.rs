use zksync_node_framework::service::ZkStackServiceBuilder;
mod heartbeat;
use heartbeat::HeartbeatLayer;
use zksync_vlog::ObservabilityBuilder;

fn main() -> anyhow::Result<()> {
    let observability = ObservabilityBuilder::default().build();

    let mut builder = ZkStackServiceBuilder::new()?;
    builder.add_layer(HeartbeatLayer);
    builder.build().run(observability)?;

    Ok(())
}