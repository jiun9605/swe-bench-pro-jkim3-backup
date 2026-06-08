"""
Test for MapTransform unification.
This test should FAIL on base commit (no MapTransform) and PASS after solution.
"""

import pytest
from sycamore.data import Document


def test_map_transform_exists():
    """MapTransform should be importable after refactor."""
    from sycamore.transforms import MapTransform

    assert MapTransform is not None


def test_map_transform_is_unified():
    """MapTransform should be the unified class."""
    from sycamore.transforms import MapTransform
    from sycamore.transforms.map import MapTransform as MT2

    assert MapTransform == MT2


def test_explode_uses_map_transform():
    """Explode should now be subclass of MapTransform."""
    from sycamore.transforms import Explode, MapTransform

    assert issubclass(Explode, MapTransform)


def test_map_transform_behavior():
    """MapTransform should handle list[Document] -> list[Document] contract."""
    from sycamore.transforms import MapTransform
    from sycamore.plan_nodes import Node

    def double_docs(docs):
        result = []
        for d in docs:
            d2 = Document(d.data.copy())
            result.append(d)
            result.append(d2)
        return result

    node = None
    mt = MapTransform(node, f=double_docs)
    docs = [Document({"x": 1}), Document({"x": 2})]
    out = mt._local_process(docs)
    assert len(out) == 4
