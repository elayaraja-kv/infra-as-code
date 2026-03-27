#!/usr/bin/env python3
"""
Compute Terragrunt unit destroy order by parsing dependency blocks.

Usage:
  python3 destroy-order.py <path>

Example:
  python3 destroy-order.py nz3es/gcp/stg/data-plane/iac-01
"""

import os
import re
import sys
from collections import defaultdict, deque

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))


def find_units(base_dir):
    """Find all terragrunt.hcl dirs under base_dir (skips cache dirs)."""
    units = []
    for root, dirs, files in os.walk(base_dir):
        dirs[:] = [d for d in dirs if d not in (".terragrunt-cache", ".terraform")]
        if "terragrunt.hcl" in files:
            units.append(os.path.normpath(root))
    return units


def resolve_config_path(raw, unit_dir, base_dir):
    """
    Resolve a config_path string to an absolute path.
    Handles:
      - Relative paths: ../../network
      - ${get_repo_root()}/...
      - ${local.base_path}/...  (base_path == base_dir for our path convention)
    """
    raw = raw.replace("${get_repo_root()}", REPO_ROOT)
    raw = raw.replace("${local.base_path}", base_dir)
    if os.path.isabs(raw):
        return os.path.normpath(raw)
    return os.path.normpath(os.path.join(unit_dir, raw))


def parse_deps(unit_dir, base_dir, unit_set):
    """Extract dependency config_paths that resolve to known units."""
    hcl_path = os.path.join(unit_dir, "terragrunt.hcl")
    deps = []
    try:
        content = open(hcl_path).read()
        # Strip full-line comments so commented-out dependency blocks are ignored
        content = re.sub(r"^\s*#.*$", "", content, flags=re.MULTILINE)
        # Find all config_path values — only dependency blocks use this key
        for m in re.finditer(r'config_path\s*=\s*"([^"]+)"', content):
            resolved = resolve_config_path(m.group(1), unit_dir, base_dir)
            if resolved in unit_set:
                deps.append(resolved)
    except FileNotFoundError:
        pass
    return deps


def topo_sort(units, deps_map):
    """
    Kahn's algorithm — returns apply order (deps first).
    Reverse for destroy order.
    """
    in_deg = {u: 0 for u in units}
    graph = defaultdict(list)  # dep -> [units that need it]

    for unit, deps in deps_map.items():
        for dep in deps:
            graph[dep].append(unit)
            in_deg[unit] += 1

    queue = deque(u for u in units if in_deg[u] == 0)
    order = []
    while queue:
        node = queue.popleft()
        order.append(node)
        for dependent in sorted(graph[node]):  # sorted for determinism
            in_deg[dependent] -= 1
            if in_deg[dependent] == 0:
                queue.append(dependent)

    if len(order) != len(units):
        remaining = set(units) - set(order)
        print("WARNING: cycle detected, unresolved units:", file=sys.stderr)
        for u in remaining:
            print(f"  {os.path.relpath(u, REPO_ROOT)}", file=sys.stderr)
    return order


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 destroy-order.py <path>")
        print("Example: python3 destroy-order.py nz3es/gcp/stg/data-plane/iac-01")
        sys.exit(1)

    base_rel = sys.argv[1]
    base_dir = os.path.normpath(os.path.join(REPO_ROOT, base_rel))

    if not os.path.isdir(base_dir):
        print(f"ERROR: directory not found: {base_dir}")
        sys.exit(1)

    units = find_units(base_dir)
    unit_set = set(units)
    deps_map = {u: parse_deps(u, base_dir, unit_set) for u in units}

    apply_order = topo_sort(units, deps_map)
    destroy_order = list(reversed(apply_order))

    W = 60
    print(f"\nDestroy order for: {base_rel}")
    print("─" * W)
    print(f"{'#':>3}  {'Unit':<40}  Dependencies")
    print("─" * W)
    for i, u in enumerate(destroy_order, 1):
        rel = os.path.relpath(u, base_dir)
        dep_names = [os.path.relpath(d, base_dir) for d in deps_map.get(u, [])]
        dep_str = ", ".join(dep_names) if dep_names else "—"
        print(f"  {i:>2}. {rel:<40}  {dep_str}")

    print()
    print("─" * W)
    print("Terragrunt commands (run in order):\n")
    for u in destroy_order:
        rel = os.path.relpath(u, REPO_ROOT)
        print(f"  terragrunt destroy --working-dir {rel}")
    print()


if __name__ == "__main__":
    main()
