use astro_core::{catalog, CelestialObject};

pub fn search(query: &str, limit: usize) -> Vec<CelestialObject> {
    let normalized = query.trim().to_lowercase();
    if normalized.is_empty() {
        return catalog().objects().iter().take(limit).cloned().collect();
    }

    let mut matches: Vec<(u8, &CelestialObject)> = catalog()
        .objects()
        .iter()
        .filter_map(|object| score(object, &normalized).map(|score| (score, object)))
        .collect();
    matches.sort_by(|left, right| {
        right
            .0
            .cmp(&left.0)
            .then_with(|| left.1.name_zh.cmp(&right.1.name_zh))
    });
    matches
        .into_iter()
        .take(limit)
        .map(|(_, object)| object.clone())
        .collect()
}

fn score(object: &CelestialObject, query: &str) -> Option<u8> {
    let candidates = std::iter::once(object.name_zh.as_str())
        .chain(std::iter::once(object.name_en.as_str()))
        .chain(object.aliases.iter().map(String::as_str));

    candidates
        .map(str::to_lowercase)
        .filter_map(|candidate| {
            if candidate == query {
                Some(100)
            } else if candidate.starts_with(query) {
                Some(80)
            } else if candidate.contains(query) {
                Some(60)
            } else {
                None
            }
        })
        .max()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn searches_multilingual_aliases() {
        assert_eq!(search("火星", 5)[0].id, "sol/mars");
        assert_eq!(search("MARS", 5)[0].id, "sol/mars");
        assert_eq!(search("luna", 5)[0].id, "sol/earth/moon");
    }
}
