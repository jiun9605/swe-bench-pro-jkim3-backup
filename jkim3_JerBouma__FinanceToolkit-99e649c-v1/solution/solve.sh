#!/bin/bash
set -euo pipefail

# The test harness (run_script.sh) and the test file both hardcode
# /app/financetoolkit/composite_scorecard.py, and the Dockerfile pins
# WORKDIR/clone to /app. Write there or fail loudly — a silent /testbed
# fallback would land the module where the tests never look.
cd /app

cat > solution_patch.diff << '__SOLUTION__'
diff --git a/financetoolkit/composite_scorecard.py b/financetoolkit/composite_scorecard.py
new file mode 100644
index 0000000..227567c
--- /dev/null
+++ b/financetoolkit/composite_scorecard.py
@@ -0,0 +1,103 @@
+"""Composite ranking scorecard with peer-quartile tiered scoring."""
+
+from __future__ import annotations
+
+import math
+
+
+def compute_composite_ranking(
+    metrics: dict[str, dict[str, float]],
+) -> dict:
+    """Compute composite ranking from pre-computed metrics.
+
+    Args:
+        metrics: Mapping of ticker -> {metric_name: value} for
+            f_score, z_prime, gross_margin, asset_turnover.
+            Missing or non-finite values are treated as absent.
+
+    Returns:
+        Dict with ranking, scores, and excluded_stocks.
+    """
+    if not metrics:
+        raise ValueError("metrics empty")
+
+    weights = {
+        "f_score": 0.40,
+        "z_prime": 0.30,
+        "gross_margin": 0.15,
+        "asset_turnover": 0.15,
+    }
+
+    # Collect valid values per metric for peer calculations
+    metric_values = {m: [] for m in weights}
+    for ticker, m_dict in metrics.items():
+        for m in weights:
+            v = m_dict.get(m)
+            if v is not None and isinstance(v, (int, float)) and math.isfinite(v):
+                metric_values[m].append(float(v))
+
+    scores = {}
+    excluded_stocks = []
+
+    for ticker, m_dict in metrics.items():
+        # Filter to valid metrics for this ticker
+        valid_metrics = {}
+        excluded = []
+        for m in weights:
+            v = m_dict.get(m)
+            if v is not None and isinstance(v, (int, float)) and math.isfinite(v):
+                valid_metrics[m] = float(v)
+            else:
+                excluded.append(m)
+
+        if not valid_metrics:
+            excluded_stocks.append({"ticker": ticker, "reason": "no usable metrics"})
+            continue
+
+        # Renormalize weights
+        total_w = sum(weights[m] for m in valid_metrics)
+        weights_applied = {m: weights[m] / total_w for m in valid_metrics}
+
+        # Compute tier points per metric
+        tier_points = {}
+        for m, v in valid_metrics.items():
+            peers = metric_values[m]
+            n = len(peers)
+            if n <= 1:
+                points = 3
+            else:
+                b = sum(1 for x in peers if x < v)
+                pr = b / (n - 1)
+                if pr < 0.25:
+                    points = 0
+                elif pr < 0.50:
+                    points = 1
+                elif pr < 0.75:
+                    points = 2
+                else:
+                    points = 3
+            tier_points[m] = points
+
+        composite = sum(weights_applied[m] * tier_points[m] for m in valid_metrics)
+
+        scores[ticker] = {
+            "composite": composite,
+            "metrics": valid_metrics,
+            "tier_points": tier_points,
+            "weights_applied": weights_applied,
+            "excluded_metrics": sorted(excluded),
+        }
+
+    # Sort by composite desc, f_score desc, ticker asc
+    def sort_key(item):
+        ticker, data = item
+        f = data["metrics"].get("f_score", -1)
+        return (-data["composite"], -f, ticker)
+
+    ranking = [t for t, _ in sorted(scores.items(), key=sort_key)]
+
+    return {
+        "ranking": ranking,
+        "scores": scores,
+        "excluded_stocks": excluded_stocks,
+    }
__SOLUTION__

git apply --verbose solution_patch.diff || patch --fuzz=5 -p1 -i solution_patch.diff
