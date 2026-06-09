#!/bin/bash
set -euo pipefail

# The FinanceToolkit repo is cloned to /app at build time (see environment/Dockerfile).
# This oracle applies the gold patch: a get_composite_scorecard() method added to the
# Toolkit controller. Fail loudly if /app is missing rather than writing nowhere useful.
cd /app

cat > solution_patch.diff << '__SOLUTION__'
diff --git a/financetoolkit/toolkit_controller.py b/financetoolkit/toolkit_controller.py
index 83a8e71..49b46c6 100644
--- a/financetoolkit/toolkit_controller.py
+++ b/financetoolkit/toolkit_controller.py
@@ -3841,3 +3841,115 @@ class Toolkit:
             _copy_normalization_files(path)
         else:
             _copy_normalization_files()
+
+    def get_composite_scorecard(
+        self, growth: bool = False, lag: int | list[int] = 1
+    ) -> pd.DataFrame:
+        """
+        Rank each company-period observation with a peer-quartile composite scorecard.
+
+        Four higher-is-better metrics are collected across the controllers — the
+        Piotroski F-Score and Altman Z-Score (from ``models``) and the gross margin
+        and asset turnover ratio (from ``ratios``) — and reshaped into a
+        (ticker, period) panel. For each metric independently, every observation is
+        scored 0-3 by its peer quartile, where the peers are all observations that
+        have a finite value for that metric: with ``b`` peers strictly below the
+        observation and ``n`` peers in total, ``pr = b / (n - 1)`` maps to 0 (pr <
+        0.25), 1 (pr < 0.50), 2 (pr < 0.75) or 3 (pr >= 0.75); a sole holder scores 3.
+        The composite is the weighted sum of those points (F-Score 0.40, Z-Score 0.30,
+        gross margin 0.15, asset turnover 0.15), renormalized over the metrics present
+        for each observation.
+
+        Args:
+            growth (bool, optional): Whether to return the period-over-period growth of
+                the composite score per ticker instead of the ranked scorecard.
+                Defaults to False.
+            lag (int | list[int], optional): The lag to use for the growth calculation.
+                Defaults to 1.
+
+        Returns:
+            pd.DataFrame: When ``growth`` is False, a frame indexed by (ticker, period)
+            sorted best to worst by composite (ties broken by F-Score descending, then
+            ticker ascending, then period descending), with columns Composite Score,
+            F-Score Points, Z-Score Points, Gross Margin Points and Asset Turnover
+            Points; a metric absent for an observation yields NaN in its points column
+            and is dropped from that observation's weighting. When ``growth`` is True, a
+            ticker-by-period frame of the period-over-period growth of the composite
+            score.
+        """
+        weights = {
+            "F-Score Points": 0.40,
+            "Z-Score Points": 0.30,
+            "Gross Margin Points": 0.15,
+            "Asset Turnover Points": 0.15,
+        }
+
+        sources = {
+            "F-Score Points": self.models.get_piotroski_score().xs(
+                "Piotroski Score", level=1
+            ),
+            "Z-Score Points": self.models.get_altman_z_score().xs(
+                "Altman Z-Score", level=1
+            ),
+            "Gross Margin Points": self.ratios.get_gross_margin(),
+            "Asset Turnover Points": self.ratios.get_asset_turnover_ratio(),
+        }
+
+        metrics = pd.DataFrame({name: frame.stack() for name, frame in sources.items()})
+        metrics.index.names = ["ticker", "period"]
+
+        tier_points = pd.DataFrame(
+            index=metrics.index, columns=list(weights), dtype=float
+        )
+        for column in weights:
+            values = metrics[column].dropna()
+            count = len(values)
+            for index, value in values.items():
+                if count <= 1:
+                    points = 3
+                else:
+                    below = int((values < value).sum())
+                    percentile_rank = below / (count - 1)
+                    if percentile_rank < 0.25:
+                        points = 0
+                    elif percentile_rank < 0.50:
+                        points = 1
+                    elif percentile_rank < 0.75:
+                        points = 2
+                    else:
+                        points = 3
+                tier_points.loc[index, column] = points
+
+        composite = {}
+        for index, row in tier_points.iterrows():
+            present = row.dropna()
+            if present.empty:
+                continue
+            total_weight = sum(weights[name] for name in present.index)
+            composite[index] = round(
+                sum(weights[name] / total_weight * present[name] for name in present.index),
+                self._rounding,
+            )
+
+        scorecard = tier_points.loc[list(composite)].copy()
+        scorecard.insert(0, "Composite Score", pd.Series(composite))
+
+        if growth:
+            composite_by_period = scorecard["Composite Score"].unstack(level="period")
+            return helpers.calculate_growth(
+                composite_by_period, lag=lag, rounding=self._rounding, axis="columns"
+            )
+
+        order = (
+            scorecard.assign(
+                _f=scorecard["F-Score Points"].fillna(-1),
+                _ticker=[index[0] for index in scorecard.index],
+                _period=[str(index[1]) for index in scorecard.index],
+            )
+            .sort_values(
+                by=["Composite Score", "_f", "_ticker", "_period"],
+                ascending=[False, False, True, False],
+            )
+            .index
+        )
+        return scorecard.loc[order]
__SOLUTION__

git apply --verbose solution_patch.diff || patch --fuzz=5 -p1 -i solution_patch.diff
