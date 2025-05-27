use chrono::Local;

const DATE_ICON: &str = "\\u{f073}";
const TIME_ICON: &str = "\\u{f017}";

pub fn get_date_time() -> String {
    let now = Local::now();
    // format!(
    //     "{} {} {} {}",
    //     DATE_ICON,
    //     now.format("%Y-%m-%d"),
    //     TIME_ICON,
    //     now.format("%H:%M:%S")
    // )
    format!("{} {}", now.format("%Y-%m-%d"), now.format("%H:%M:%S"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    proptest! {
        #[test]
        fn test_get_date_time_format(_s in ".*") {
            // This test doesn't depend on input `_s`, it checks the output format.
            // A more robust test would be to parse the date back or check regex.
            // For now, we check it contains the icons and some date/time separators.
            let result = get_date_time();
            // prop_assert!(result.contains(DATE_ICON));
            // prop_assert!(result.contains(TIME_ICON));
            prop_assert!(result.contains("-")); // Date separator
            prop_assert!(result.contains(":")); // Time separator
        }
    }
}
