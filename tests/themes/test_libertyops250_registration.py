"""Registration and persistence checks for Liberty Ops 250."""
from pathlib import Path
import unittest

from theme_registration import make_theme_test_case

ThemeRegistrationTests = make_theme_test_case(
    Path(__file__).with_name("libertyops250_registration.json"), __name__
)

if __name__ == "__main__":
    unittest.main()
