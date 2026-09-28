"""libudev: repacked runtime library recipe"""
from tests.lib.desktop_runtime_checks import check_recipe, check_index
import pytest

@pytest.mark.static
def test_recipe():
    check_recipe("libudev")

@pytest.mark.index
def test_index():
    check_index("libudev")
