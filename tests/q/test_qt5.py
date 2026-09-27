"""Qt 5 配方验证"""
import pytest
from tests.lib.desktop_runtime_checks import check_recipe, check_index


@pytest.mark.static
def test_recipe():
    check_recipe("qt5")


@pytest.mark.index
def test_index():
    check_index("qt5")
