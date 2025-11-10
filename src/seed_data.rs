//! Seed data configuration for NIP-47 wallet service
use crate::config::SeedData;
use crate::error::Result;
use crate::event::Event;
use tracing::info;

/// Build a NIP-47 info event (kind 13194) from pre-signed configuration
#[allow(clippy::result_large_err)]
pub fn create_nip47_info_event(config: &SeedData) -> Result<Event> {
    info!(
        "Loading pre-signed NIP-47 info event (pubkey: {}, id: {})",
        &config.pubkey[..16],
        &config.id[..16]
    );

    // Build the content field: space-separated list of commands
    let content = config.commands.join(" ");

    // Build tags
    let mut tags = Vec::new();

    // Add encryption tag if methods are specified
    if !config.encryption_methods.is_empty() {
        let encryption_value = config.encryption_methods.join(" ");
        tags.push(vec!["encryption".to_string(), encryption_value]);
    }

    // Build the event from the pre-signed config fields
    let event = Event {
        id: config.id.clone(),
        pubkey: config.pubkey.clone(),
        delegated_by: None,
        created_at: config.created_at,
        kind: 13194,
        tags,
        content,
        sig: config.sig.clone(),
        tagidx: None,
    };

    // Validate the event signature
    event.validate()?;

    Ok(event)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_seed_event_from_presigned() {
        // This is a real pre-signed event created with the test key
        let config = SeedData {
            id: "9856192b4968ba1f597aada2291d2adaf2f785091db91504caed67d4454e022c".to_owned(),
            pubkey: "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798".to_owned(),
            created_at: 1700000000,
            sig: "8b9daa3dcad3d436d32b087688b86bb18eb4c81d907a46a73be096f7caa2dc02a1e0dd8507dde56c28964af0e25fd56f07aac6acb112b8bf15c84f3a75ec11a0".to_owned(),
            commands: vec!["get_info".to_string()],
            encryption_methods: vec!["nip44_v2".to_string()],
        };

        let event = create_nip47_info_event(&config).unwrap();

        // Verify kind is 13194
        assert_eq!(event.kind, 13194);

        // Verify content contains "get_info"
        assert!(event.content.contains("get_info"));

        // Verify tags contain encryption
        assert!(!event.tags.is_empty());

        // Verify has correct pubkey
        assert_eq!(
            event.pubkey,
            "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        );
    }
}
