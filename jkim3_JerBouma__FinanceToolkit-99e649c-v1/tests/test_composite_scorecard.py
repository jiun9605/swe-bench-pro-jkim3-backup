"""Tests for the composite scorecard on the Toolkit controller."""

import math

import pandas as pd

from financetoolkit import Toolkit

balance = pd.read_pickle("tests/datasets/balance_dataset.pickle")
income = pd.read_pickle("tests/datasets/income_dataset.pickle")
cash = pd.read_pickle("tests/datasets/cash_dataset.pickle")
historical = pd.read_pickle("tests/datasets/historical_dataset.pickle")


def build_toolkit():
    return Toolkit(
        tickers=["AAPL", "MSFT"],
        historical=historical,
        balance=balance,
        income=income,
        cash=cash,
        convert_currency=False,
        start_date="2019-12-31",
        end_date="2023-01-01",
        sleep_timer=False,
    )


def test_scorecard_structure():
    sc = build_toolkit().get_composite_scorecard()
    assert isinstance(sc, pd.DataFrame)
    assert list(sc.columns) == [
        "Composite Score",
        "F-Score Points",
        "Z-Score Points",
        "Gross Margin Points",
        "Asset Turnover Points",
    ]
    assert list(sc.index.names) == ["ticker", "period"]
    assert sc.shape == (8, 5)


def test_scorecard_ranking_order():
    sc = build_toolkit().get_composite_scorecard()
    order = [(t, str(p)) for t, p in sc.index]
    assert order == [
        ("AAPL", "2023"),
        ("AAPL", "2022"),
        ("MSFT", "2021"),
        ("MSFT", "2020"),
        ("AAPL", "2021"),
        ("MSFT", "2022"),
        ("MSFT", "2023"),
        ("AAPL", "2020"),
    ]


def test_scorecard_composite_values():
    sc = build_toolkit().get_composite_scorecard()
    comp = sc["Composite Score"].tolist()
    assert comp[0] == 2.5714  # best: AAPL 2023
    assert comp[-1] == 0.0  # worst: AAPL 2020
    # MSFT 2020 has only z_score + gross_margin -> weights renormalize to 0.30/0.45 and 0.15/0.45
    assert sc["Composite Score"].iloc[3] == 1.3333


def test_scorecard_tier_points_and_quartiles():
    sc = build_toolkit().get_composite_scorecard()
    top = sc.iloc[0]  # AAPL 2023
    assert top["F-Score Points"] == 3.0
    assert top["Gross Margin Points"] == 1.0
    assert top["Asset Turnover Points"] == 3.0
    # mid-tier (2) is exercised, not just 0/3
    assert sc["Z-Score Points"].dropna().isin([0.0, 1.0, 2.0, 3.0]).all()
    assert (sc["Z-Score Points"] == 2.0).any()


def test_scorecard_missing_metric_handling():
    sc = build_toolkit().get_composite_scorecard()
    # Altman Z is unavailable in 2023 -> NaN points, dropped from weighting
    assert math.isnan(sc.iloc[0]["Z-Score Points"])
    # 2020 observations lack F-Score and Asset Turnover
    msft_2020 = sc.iloc[3]
    assert math.isnan(msft_2020["F-Score Points"])
    assert math.isnan(msft_2020["Asset Turnover Points"])
    assert msft_2020["Z-Score Points"] == 1.0
    assert msft_2020["Gross Margin Points"] == 2.0


def test_scorecard_growth_shape_and_values():
    g = build_toolkit().get_composite_scorecard(growth=True)
    assert isinstance(g, pd.DataFrame)
    assert list(g.index) == ["AAPL", "MSFT"]
    assert g.shape == (2, 4)
    # first period has no prior -> NaN growth for both tickers
    assert math.isnan(g.iloc[0, 0])
    assert math.isnan(g.iloc[1, 0])
    # clean period-over-period composite growth
    assert g.iloc[0, 2] == 0.5      # AAPL 2022 vs 2021
    assert g.iloc[0, 3] == 0.4286   # AAPL 2023 vs 2022
    assert g.iloc[1, 1] == 0.0125   # MSFT 2021 vs 2020
    assert g.iloc[1, 2] == -0.2222  # MSFT 2022 vs 2021
    assert g.iloc[1, 3] == -0.3877  # MSFT 2023 vs 2022


def test_scorecard_growth_zero_base_edge():
    g = build_toolkit().get_composite_scorecard(growth=True)
    # AAPL's 2020 composite is 0, so 2021 growth divides by zero -> inf
    assert math.isinf(g.iloc[0, 1])
