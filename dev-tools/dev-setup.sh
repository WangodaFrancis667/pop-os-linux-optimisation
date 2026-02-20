#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  LEGACY SCRIPT — This file is kept for backwards compatibility.             ║
# ║                                                                              ║
# ║  The toolkit has been restructured into interactive, modular scripts.        ║
# ║  Please use the new entry point instead:                                     ║
# ║                                                                              ║
# ║      cd .. && ./install.sh                                                   ║
# ║                                                                              ║
# ║  Or run individual modules:                                                  ║
# ║      ../scripts/dev-setup.sh       Developer tools                           ║
# ║      ../scripts/ai-setup.sh        AI / ML workstation                       ║
# ║      ../scripts/gaming-setup.sh    Gaming optimization                       ║
# ║      ../scripts/robotics-setup.sh  Robotics lab (ROS 2)                      ║
# ║      ../scripts/ssh-setup.sh       SSH configuration                         ║
# ║      ../scripts/system-optimize.sh System performance tuning                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo ""
echo "  ⚠  This script has been replaced by the interactive installer."
echo ""
echo "  Run the new toolkit:"
echo "    cd ${TOOLKIT_ROOT} && ./install.sh"
echo ""
echo "  Or install everything non-interactively:"
echo "    cd ${TOOLKIT_ROOT} && ./install.sh --all"
echo ""

read -rp "  Launch the new installer now? [Y/n] " answer
if [[ "${answer:-y}" =~ ^[Yy] ]]; then
    exec bash "${TOOLKIT_ROOT}/install.sh"
fi