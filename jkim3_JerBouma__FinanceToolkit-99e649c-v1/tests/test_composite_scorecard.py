"""Tests for composite scorecard ranking."""

import math

import pytest

def get_compute():
    import importlib.util
    import os
    # Load module directly to avoid package build dependencies
    module_path = "/app/financetoolkit/composite_scorecard.py"
    if not os.path.exists(module_path):
        # Module doesn't exist at baseline - return stub that will fail tests
        def stub_compute(metrics):
            raise AssertionError("Module not implemented yet")
        return stub_compute
    spec = importlib.util.spec_from_file_location(
        "composite_scorecard",
        module_path
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.compute_composite_ranking


def test_composite_ranking_basic():
    """Test basic ranking with all metrics present."""
    metrics = {
        "AAA": {"f_score": 7, "z_prime": 3.4, "gross_margin": 0.52, "asset_turnover": 0.9},
        "BBB": {"f_score": 8, "z_prime": 4.2, "gross_margin": 0.68, "asset_turnover": 0.7},
        "CCC": {"f_score": 5, "z_prime": 2.1, "gross_margin": 0.35, "asset_turnover": 1.2},
        "DDD": {"f_score": 6, "z_prime": 2.8, "gross_margin": 0.45, "asset_turnover": 1.0},
    }
    result = get_compute()(metrics)
    
    assert result["ranking"][0] == "BBB"  # highest composite
    assert len(result["ranking"]) == 4
    assert result["excluded_stocks"] == []
    
    # Check BBB has top scores
    bbb = result["scores"]["BBB"]
    assert bbb["composite"] == pytest.approx(2.55, abs=1e-9)
    assert bbb["tier_points"]["f_score"] == 3
    assert bbb["excluded_metrics"] == []


def test_missing_metric_exclusion():
    """Test that missing metrics are excluded and weights renormalized."""
    metrics = {
        "AAA": {"f_score": 7, "z_prime": 3.4, "gross_margin": 0.52, "asset_turnover": 0.9},
        "FFF": {"f_score": 4, "z_prime": 1.5, "asset_turnover": 0.5},  # missing gross_margin
    }
    result = get_compute()(metrics)
    
    fff = result["scores"]["FFF"]
    assert "gross_margin" not in fff["metrics"]
    assert "gross_margin" in fff["excluded_metrics"]
    # Weights should be renormalized: 0.4/0.85, 0.3/0.85, 0.15/0.85
    assert fff["weights_applied"]["f_score"] == pytest.approx(0.4 / 0.85, abs=1e-9)
    assert abs(sum(fff["weights_applied"].values()) - 1.0) < 1e-9
    # Excluded metric must be absent from tier_points, not present as None
    assert "gross_margin" not in fff["tier_points"]
    # AAA is the sole holder of gross_margin (FFF lacks it) -> sole-holder scores 3
    assert result["scores"]["AAA"]["tier_points"]["gross_margin"] == 3


def test_tie_breaking():
    """Test deterministic tie-breaking by f_score then ticker."""
    metrics = {
        "AAA": {"f_score": 7, "z_prime": 3.4, "gross_margin": 0.52, "asset_turnover": 0.9},
        "EEE": {"f_score": 7, "z_prime": 3.4, "gross_margin": 0.52, "asset_turnover": 0.9},  # identical to AAA
        "BBB": {"f_score": 8, "z_prime": 4.2, "gross_margin": 0.68, "asset_turnover": 0.7},
    }
    result = get_compute()(metrics)
    
    # AAA and EEE should tie on composite and f_score, so AAA wins by ticker asc
    aaa_idx = result["ranking"].index("AAA")
    eee_idx = result["ranking"].index("EEE")
    assert aaa_idx < eee_idx


def test_nan_handling():
    """Test that NaN values are treated as missing."""
    metrics = {
        "AAA": {"f_score": 7, "z_prime": 3.4, "gross_margin": 0.52, "asset_turnover": 0.9},
        "NAN": {"f_score": 5, "z_prime": 2.0, "gross_margin": float("nan"), "asset_turnover": float("nan")},
    }
    result = get_compute()(metrics)
    
    nan_stock = result["scores"]["NAN"]
    assert "gross_margin" in nan_stock["excluded_metrics"]
    assert "asset_turnover" in nan_stock["excluded_metrics"]
    assert "gross_margin" not in nan_stock["metrics"]


def test_error_conditions():
    """Test ValueError on empty input."""
    with pytest.raises(ValueError, match="empty"):
        get_compute()({})
    
    # Stock with no usable metrics should be excluded, not raise
    result = get_compute()({
        "BAD": {"f_score": float("nan"), "z_prime": None},
        "GOOD": {"f_score": 5, "z_prime": 2.0, "gross_margin": 0.3, "asset_turnover": 1.0},
    })
    assert len(result["excluded_stocks"]) == 1
    assert result["excluded_stocks"][0]["ticker"] == "BAD"
    # Excluded stock must carry a non-empty reason string
    assert isinstance(result["excluded_stocks"][0]["reason"], str)
    assert result["excluded_stocks"][0]["reason"]


if __name__ == "__main__":
    import sys
    # Simple test runner outputting pytest-compatible format for parser
    tests = [
        ("tests/test_composite_scorecard.py::test_composite_ranking_basic", test_composite_ranking_basic),
        ("tests/test_composite_scorecard.py::test_missing_metric_exclusion", test_missing_metric_exclusion),
        ("tests/test_composite_scorecard.py::test_tie_breaking", test_tie_breaking),
        ("tests/test_composite_scorecard.py::test_nan_handling", test_nan_handling),
        ("tests/test_composite_scorecard.py::test_error_conditions", test_error_conditions),
    ]
    failed = 0
    for test_name, test in tests:
        try:
            test()
            print(f"{test_name} PASSED")
        except Exception as e:
            print(f"{test_name} FAILED: {type(e).__name__}: {e}")
            import traceback, sys
            traceback.print_exc(file=sys.stdout)
            failed += 1
    sys.exit(0)
