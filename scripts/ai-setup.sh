#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Pop!_OS Optimization Toolkit — AI / ML Workstation Setup                   ║
# ║                                                                              ║
# ║  Installs local AI inference, CUDA stack, model runners, and web UIs.        ║
# ║  Detects GPU VRAM and recommends appropriate models for your hardware.       ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ─────────────────────────────────────────────────────────────
#  Package Groups
# ─────────────────────────────────────────────────────────────
AI_LABELS=(
    "NVIDIA Drivers & CUDA   (nvidia-driver, cuda-toolkit)"
    "Ollama                  (Local LLM inference engine)"
    "Open WebUI              (ChatGPT-style web interface)"
    "Python ML Stack         (PyTorch, transformers, accelerate)"
    "Jupyter Lab             (Interactive notebook environment)"
    "Computer Vision         (OpenCV, ultralytics YOLO)"
    "LangChain & RAG Tools   (langchain, chromadb, sentence-transformers)"
    "Text Generation WebUI   (oobabooga/text-generation-webui)"
)

AI_SELECTED=(1 1 1 1 1 1 0 0)

# ─────────────────────────────────────────────────────────────
#  GPU-Aware Model Recommendations
# ─────────────────────────────────────────────────────────────
print_model_recommendations() {
    local vram gpu_tier
    vram=$(detect_gpu_vram)
    gpu_tier=$(detect_gpu_tier)

    local width=58
    echo ""
    draw_box_top $width "$MAGENTA"
    draw_box_line_centered "Recommended Models for Your GPU" $width "$MAGENTA" "${BOLD}${WHITE}"
    draw_box_middle $width "$MAGENTA"

    case "$gpu_tier" in
        ultra)  # 24GB+
            draw_box_line "  ${GREEN}VRAM: ${vram} MB — Ultra Tier${NC}" $width "$MAGENTA" "$NC"
            draw_box_middle $width "$MAGENTA"
            draw_box_line "  Model               Command" $width "$MAGENTA" "${BOLD}${WHITE}"
            draw_box_middle $width "$MAGENTA"
            draw_box_line "  Llama 3.1 70B       ollama run llama3.1:70b" $width "$MAGENTA" "$NC"
            draw_box_line "  Mixtral 8x7B        ollama run mixtral" $width "$MAGENTA" "$NC"
            draw_box_line "  CodeLlama 34B       ollama run codellama:34b" $width "$MAGENTA" "$NC"
            draw_box_line "  DeepSeek Coder 33B  ollama run deepseek-coder:33b" $width "$MAGENTA" "$NC"
            draw_box_line "  Llama 3.1 8B        ollama run llama3.1" $width "$MAGENTA" "$NC"
            ;;
        high)   # 16GB
            draw_box_line "  ${GREEN}VRAM: ${vram} MB — High Tier${NC}" $width "$MAGENTA" "$NC"
            draw_box_middle $width "$MAGENTA"
            draw_box_line "  Model               Command" $width "$MAGENTA" "${BOLD}${WHITE}"
            draw_box_middle $width "$MAGENTA"
            draw_box_line "  Llama 3.1 8B        ollama run llama3.1" $width "$MAGENTA" "$NC"
            draw_box_line "  Mixtral 8x7B (Q4)   ollama run mixtral" $width "$MAGENTA" "$NC"
            draw_box_line "  CodeLlama 13B       ollama run codellama:13b" $width "$MAGENTA" "$NC"
            draw_box_line "  DeepSeek Coder V2   ollama run deepseek-coder-v2" $width "$MAGENTA" "$NC"
            draw_box_line "  Phi-3 Medium        ollama run phi3:medium" $width "$MAGENTA" "$NC"
            ;;
        medium) # 8GB
            draw_box_line "  ${YELLOW}VRAM: ${vram} MB — Medium Tier${NC}" $width "$MAGENTA" "$NC"
            draw_box_middle $width "$MAGENTA"
            draw_box_line "  Model               Command" $width "$MAGENTA" "${BOLD}${WHITE}"
            draw_box_middle $width "$MAGENTA"
            draw_box_line "  Llama 3.1 8B        ollama run llama3.1" $width "$MAGENTA" "$NC"
            draw_box_line "  Mistral 7B          ollama run mistral" $width "$MAGENTA" "$NC"
            draw_box_line "  CodeLlama 7B        ollama run codellama" $width "$MAGENTA" "$NC"
            draw_box_line "  Phi-3 Mini          ollama run phi3" $width "$MAGENTA" "$NC"
            draw_box_line "  Gemma 2 9B          ollama run gemma2" $width "$MAGENTA" "$NC"
            ;;
        entry)  # 4-6GB  (RTX A1000, GTX 1650)
            draw_box_line "  ${ORANGE}VRAM: ${vram} MB — Entry Tier${NC}" $width "$MAGENTA" "$NC"
            draw_box_line "  ${DIM}Quantized models recommended (Q4_K_M)${NC}" $width "$MAGENTA" "$NC"
            draw_box_middle $width "$MAGENTA"
            draw_box_line "  Model               Command" $width "$MAGENTA" "${BOLD}${WHITE}"
            draw_box_middle $width "$MAGENTA"
            draw_box_line "  Llama 3.2 3B        ollama run llama3.2:3b" $width "$MAGENTA" "$NC"
            draw_box_line "  Phi-3 Mini (3.8B)   ollama run phi3" $width "$MAGENTA" "$NC"
            draw_box_line "  Mistral 7B (Q4)     ollama run mistral" $width "$MAGENTA" "$NC"
            draw_box_line "  CodeLlama 7B (Q4)   ollama run codellama" $width "$MAGENTA" "$NC"
            draw_box_line "  TinyLlama 1.1B      ollama run tinyllama" $width "$MAGENTA" "$NC"
            draw_box_line "  Gemma 2B            ollama run gemma:2b" $width "$MAGENTA" "$NC"
            ;;
        *)      # Unknown or minimal
            draw_box_line "  ${RED}GPU not detected or minimal VRAM${NC}" $width "$MAGENTA" "$NC"
            draw_box_line "  ${DIM}CPU-only inference recommended${NC}" $width "$MAGENTA" "$NC"
            draw_box_middle $width "$MAGENTA"
            draw_box_line "  Model               Command" $width "$MAGENTA" "${BOLD}${WHITE}"
            draw_box_middle $width "$MAGENTA"
            draw_box_line "  TinyLlama 1.1B      ollama run tinyllama" $width "$MAGENTA" "$NC"
            draw_box_line "  Phi-3 Mini          ollama run phi3" $width "$MAGENTA" "$NC"
            draw_box_line "  Gemma 2B            ollama run gemma:2b" $width "$MAGENTA" "$NC"
            ;;
    esac

    draw_empty_line $width "$MAGENTA"
    draw_box_bottom $width "$MAGENTA"
    echo ""
}

# ─────────────────────────────────────────────────────────────
#  Installation Functions
# ─────────────────────────────────────────────────────────────

install_nvidia_cuda() {
    print_section "NVIDIA Drivers & CUDA Toolkit"

    # Pop!_OS ships with NVIDIA drivers in the NVIDIA ISO
    if command_exists nvidia-smi; then
        local driver_ver
        driver_ver=$(detect_nvidia_driver)
        log_info "NVIDIA driver already installed: v${driver_ver}"
    else
        log_info "Installing NVIDIA driver..."
        sudo apt install -y system76-driver-nvidia 2>/dev/null || \
        sudo apt install -y nvidia-driver-535 2>/dev/null || \
        log_warning "Could not auto-install NVIDIA driver. Install via Pop!_Shop or: sudo apt install system76-driver-nvidia"
    fi

    # CUDA Toolkit
    if ! command_exists nvcc; then
        log_info "Installing CUDA Toolkit..."
        apt_install nvidia-cuda-toolkit
    else
        log_info "CUDA already installed: $(detect_cuda_version)"
    fi

    # cuDNN (for deep learning)
    apt_install nvidia-cudnn 2>/dev/null || log_info "cuDNN package not found in repos (install manually if needed)."

    # Verification tools
    apt_install nvidia-settings nvtop

    log_success "NVIDIA drivers & CUDA installed."
    echo ""
    echo -e "  ${DIM}Verify with: nvidia-smi && nvcc --version${NC}"
}

install_ollama() {
    print_section "Ollama — Local LLM Engine"

    if command_exists ollama; then
        log_info "Ollama already installed: $(ollama --version 2>/dev/null || echo 'installed')"
    else
        log_info "Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh
    fi

    # Ensure Ollama service is running
    if systemctl is-active --quiet ollama 2>/dev/null; then
        log_info "Ollama service is already running."
    else
        sudo systemctl enable --now ollama 2>/dev/null || \
        log_warning "Could not start Ollama service. Start manually with: ollama serve"
    fi

    log_success "Ollama installed and running."

    # Show model recommendations
    print_model_recommendations

    # Offer to pull a starter model
    if confirm "Pull a starter model now? (phi3 — fast & lightweight)"; then
        log_info "Pulling phi3 model (this may take a few minutes)..."
        ollama pull phi3
        log_success "Model phi3 ready. Run with: ollama run phi3"
    fi
}

install_open_webui() {
    print_section "Open WebUI — ChatGPT-style Interface"

    if ! command_exists docker; then
        log_warning "Docker is required for Open WebUI. Install Docker first."
        if confirm "Install Docker now?"; then
            apt_install docker-ce docker-ce-cli containerd.io \
                docker-buildx-plugin docker-compose-plugin
            sudo usermod -aG docker "$USER"
        else
            log_warning "Skipping Open WebUI (Docker required)."
            return 0
        fi
    fi

    log_info "Deploying Open WebUI container..."

    # Stop existing container if running
    docker stop open-webui 2>/dev/null || true
    docker rm open-webui 2>/dev/null || true

    docker run -d \
        --name open-webui \
        --restart unless-stopped \
        -p 3000:8080 \
        -v open-webui-data:/app/backend/data \
        --add-host=host.docker.internal:host-gateway \
        ghcr.io/open-webui/open-webui:main

    log_success "Open WebUI deployed."
    echo ""
    echo -e "  ${BOLD}${CYAN}Access at:${NC} ${UNDERLINE}http://localhost:3000${NC}"
    echo -e "  ${DIM}First visit will prompt you to create an admin account.${NC}"
    echo -e "  ${DIM}It connects to Ollama automatically on localhost:11434.${NC}"
    echo ""
}

install_python_ml() {
    print_section "Python ML Stack"

    # Create a virtual environment for ML work
    local ml_venv="$HOME/.venvs/ml"

    if [ ! -d "$ml_venv" ]; then
        log_info "Creating ML virtual environment at ${ml_venv}..."
        python3 -m venv "$ml_venv"
    fi

    log_info "Installing PyTorch with CUDA support..."
    "$ml_venv/bin/pip" install --upgrade pip

    # Detect CUDA for correct PyTorch version
    if command_exists nvcc; then
        log_info "CUDA detected — installing GPU-accelerated PyTorch..."
        "$ml_venv/bin/pip" install torch torchvision torchaudio \
            --index-url https://download.pytorch.org/whl/cu121
    else
        log_warning "CUDA not detected — installing CPU-only PyTorch."
        "$ml_venv/bin/pip" install torch torchvision torchaudio \
            --index-url https://download.pytorch.org/whl/cpu
    fi

    "$ml_venv/bin/pip" install transformers accelerate datasets \
        sentencepiece tokenizers safetensors bitsandbytes \
        huggingface-hub evaluate

    log_success "Python ML stack installed in: ${ml_venv}"
    echo ""
    echo -e "  ${DIM}Activate with: source ~/.venvs/ml/bin/activate${NC}"
}

install_jupyter() {
    print_section "Jupyter Lab"

    local ml_venv="$HOME/.venvs/ml"
    local jupyter_pip="pip3"

    if [ -d "$ml_venv" ]; then
        jupyter_pip="$ml_venv/bin/pip"
    fi

    $jupyter_pip install --upgrade jupyterlab ipykernel ipywidgets \
        notebook nbconvert

    # Register kernel
    if [ -d "$ml_venv" ]; then
        "$ml_venv/bin/python" -m ipykernel install --user --name ml --display-name "Python (ML)"
    fi

    log_success "Jupyter Lab installed."
    echo ""
    echo -e "  ${DIM}Launch with: jupyter lab${NC}"
    echo -e "  ${DIM}Or from ML venv: source ~/.venvs/ml/bin/activate && jupyter lab${NC}"
}

install_computer_vision() {
    print_section "Computer Vision Stack"

    local ml_venv="$HOME/.venvs/ml"
    local cv_pip="pip3"

    if [ -d "$ml_venv" ]; then
        cv_pip="$ml_venv/bin/pip"
    fi

    $cv_pip install opencv-python opencv-python-headless \
        ultralytics supervision

    # System dependencies for OpenCV
    apt_install libgl1-mesa-glx libglib2.0-0 2>/dev/null || true

    log_success "Computer vision stack installed."
}

install_langchain() {
    print_section "LangChain & RAG Tools"

    local ml_venv="$HOME/.venvs/ml"
    local lc_pip="pip3"

    if [ -d "$ml_venv" ]; then
        lc_pip="$ml_venv/bin/pip"
    fi

    $lc_pip install langchain langchain-community langchain-core \
        chromadb sentence-transformers faiss-cpu \
        unstructured pymupdf

    log_success "LangChain & RAG tools installed."
}

install_text_gen_webui() {
    print_section "Text Generation WebUI (oobabooga)"

    local install_dir="$HOME/text-generation-webui"

    if [ -d "$install_dir" ]; then
        log_info "Text Generation WebUI already exists at ${install_dir}."
        if confirm "Update existing installation?"; then
            cd "$install_dir"
            git pull
        else
            return 0
        fi
    else
        log_info "Cloning Text Generation WebUI..."
        git clone https://github.com/oobabooga/text-generation-webui.git "$install_dir"
        cd "$install_dir"
    fi

    log_info "Running installer (this may take several minutes)..."
    bash start_linux.sh --auto

    log_success "Text Generation WebUI installed at: ${install_dir}"
    echo ""
    echo -e "  ${DIM}Launch with: cd ~/text-generation-webui && bash start_linux.sh${NC}"
}

# ─────────────────────────────────────────────────────────────
#  Installer Dispatch
# ─────────────────────────────────────────────────────────────
AI_FUNCTIONS=(
    install_nvidia_cuda
    install_ollama
    install_open_webui
    install_python_ml
    install_jupyter
    install_computer_vision
    install_langchain
    install_text_gen_webui
)

# ─────────────────────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────────────────────
main() {
    clear_screen
    echo ""
    echo -e "  ${BOLD}${WHITE}AI / ML Workstation Setup${NC}"
    echo -e "  ${DIM}Transform your machine into a local AI powerhouse.${NC}"
    echo ""

    # Show GPU info
    local gpu gpu_vram driver_ver
    gpu=$(detect_gpu)
    gpu_vram=$(detect_gpu_vram)
    driver_ver=$(detect_nvidia_driver)

    echo -e "  ${CYAN}GPU:${NC}     ${gpu}"
    echo -e "  ${CYAN}VRAM:${NC}    ${gpu_vram} MB"
    echo -e "  ${CYAN}Driver:${NC}  ${driver_ver}"
    echo ""

    # Detect existing tools
    log_info "Scanning existing installations..."
    command_exists nvidia-smi && log_info "NVIDIA driver: installed" || true
    command_exists ollama     && log_info "Ollama: installed" || true
    command_exists docker     && log_info "Docker: installed" || true
    echo ""

    # Show checklist
    if ! show_checklist "AI/ML Workstation — Select Components" AI_SELECTED AI_LABELS; then
        log_info "Cancelled."
        return 0
    fi

    # Count selected
    local count=0
    for s in "${AI_SELECTED[@]}"; do ((count += s)); done

    if [ "$count" -eq 0 ]; then
        log_warning "No components selected."
        return 0
    fi

    echo ""
    log_info "${count} component(s) selected."
    if ! confirm "Proceed with installation?"; then
        return 0
    fi

    ensure_sudo
    check_internet || return 1

    # System update
    print_section "Updating Package Lists" "↻"
    sudo apt update 2>&1 | tee -a "$LOG_FILE"

    # Install selected
    local total=$count current=0
    for i in "${!AI_SELECTED[@]}"; do
        if [ "${AI_SELECTED[$i]}" -eq 1 ]; then
            ((current++))
            echo ""
            log_step "$current" "$total" "${AI_LABELS[$i]%%(*}"
            ${AI_FUNCTIONS[$i]}
            progress_bar "$current" "$total" 40 "  Overall"
        fi
    done

    # Show final model recommendations
    print_model_recommendations

    print_completion_banner "AI/ML Workstation Setup Complete"

    echo -e "  ${BOLD}Quick Start:${NC}"
    echo -e "    ${TEAL}1.${NC} Run a model:    ${DIM}ollama run phi3${NC}"
    echo -e "    ${TEAL}2.${NC} Open WebUI:     ${DIM}http://localhost:3000${NC}"
    echo -e "    ${TEAL}3.${NC} ML Python env:  ${DIM}source ~/.venvs/ml/bin/activate${NC}"
    echo -e "    ${TEAL}4.${NC} Jupyter Lab:    ${DIM}jupyter lab${NC}"
    echo ""

    echo -e "  ${DIM}Press Enter to continue...${NC}"
    read -r
}

main "$@"
