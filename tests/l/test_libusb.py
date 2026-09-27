"""libusb 运行库配方验证"""
from tests.lib.desktop_runtime_checks import check_recipe, check_index
import pytest

@pytest.mark.static
def test_recipe():
    check_recipe("libusb")

@pytest.mark.index
def test_index():
    check_index("libusb")
