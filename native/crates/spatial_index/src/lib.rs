use ephemeris_engine::ObjectPosition;

#[derive(Clone, Copy, Debug)]
pub struct Viewport {
    pub min_x_au: f64,
    pub max_x_au: f64,
    pub min_y_au: f64,
    pub max_y_au: f64,
}

pub fn visible_objects(positions: &[ObjectPosition], viewport: Viewport) -> Vec<ObjectPosition> {
    positions
        .iter()
        .filter(|position| {
            position.x_au >= viewport.min_x_au
                && position.x_au <= viewport.max_x_au
                && position.y_au >= viewport.min_y_au
                && position.y_au <= viewport.max_y_au
        })
        .cloned()
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use ephemeris_engine::positions_at;

    #[test]
    fn viewport_query_removes_far_outer_objects() {
        let visible = visible_objects(
            &positions_at(0.0),
            Viewport {
                min_x_au: -2.0,
                max_x_au: 2.0,
                min_y_au: -2.0,
                max_y_au: 2.0,
            },
        );
        assert!(visible.iter().any(|item| item.id == "sol/earth"));
        assert!(!visible.iter().any(|item| item.id == "sol/neptune"));
    }
}
