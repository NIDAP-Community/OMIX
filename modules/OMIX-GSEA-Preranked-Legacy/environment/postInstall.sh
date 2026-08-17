#!/usr/bin/env bash
set -euo pipefail

echo "========== GSEA postInstall.sh =========="
Rscript --vanilla - <<'EOF'
message("Installing l2p and l2psupp from CCBR GitHub releases...")

install.packages(
  "https://github.com/CCBR/l2p/raw/master/l2p_0.0-14.tar.gz",
  repos = NULL,
  type = "source"
)

install.packages(
  "https://github.com/CCBR/l2p/raw/master/l2psupp_0.0-14.tar.gz",
  repos = NULL,
  type = "source"
)

message("✓ l2p and l2psupp installed")
EOF
echo "========== postInstall complete =========="


