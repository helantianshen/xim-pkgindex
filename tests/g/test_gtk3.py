"""gtk3 运行库配方验证"""
from tests.lib.desktop_runtime_checks import check_recipe, check_index
import pytest

@pytest.mark.static
def test_recipe():
    check_recipe("gtk3")

@pytest.mark.index
def test_index():
    check_index("gtk3")
