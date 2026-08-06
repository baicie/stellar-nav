use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct OfflinePackManifest {
    pub schema_version: u16,
    pub pack_id: String,
    pub system_id: String,
    pub minimum_zoom: u8,
    pub maximum_zoom: u8,
    pub checksum_sha256: String,
}

pub fn decode_manifest(payload: &str) -> Result<OfflinePackManifest, String> {
    let manifest: OfflinePackManifest =
        serde_json::from_str(payload).map_err(|error| error.to_string())?;
    if manifest.schema_version != 1 {
        return Err(format!(
            "unsupported tile schema {}",
            manifest.schema_version
        ));
    }
    if manifest.minimum_zoom > manifest.maximum_zoom {
        return Err("minimum zoom cannot exceed maximum zoom".into());
    }
    Ok(manifest)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_unknown_schema_versions() {
        let payload = r#"{"schemaVersion":9,"packId":"sol","systemId":"sol","minimumZoom":0,"maximumZoom":4,"checksumSha256":"demo"}"#;
        assert!(decode_manifest(payload).is_err());
    }
}
