use zk_ee::{common_structs::derive_flat_storage_key, utils::Bytes32};
use zksync_types::{address_to_h256, h256_to_address, Address, H256};

use crate::zkos_conversions::{bytes32_to_h256, h256_to_bytes32};

pub mod zkos_conversions;

pub fn zkos_nonce_flat_key(address: Address) -> H256 {
    let nonce_holder = todo!();
    let key = h256_to_bytes32(address_to_h256(&address));
    bytes32_to_h256(derive_flat_storage_key(&nonce_holder, &key))
}
