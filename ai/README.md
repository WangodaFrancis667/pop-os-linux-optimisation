# AI / ML Workstation Guide

> Transform your Pop!\_OS machine into a local AI powerhouse — completely offline, fully private.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Setup (Script)](#quick-setup-script)
- [Ollama — Local LLM Engine](#ollama--local-llm-engine)
- [Model Recommendations by GPU](#model-recommendations-by-gpu)
- [Open WebUI — ChatGPT-Style Interface](#open-webui--chatgpt-style-interface)
- [Python ML Stack](#python-ml-stack)
- [Jupyter Lab](#jupyter-lab)
- [API Access from Python](#api-access-from-python)
- [LangChain & RAG](#langchain--rag)
- [Troubleshooting](#troubleshooting)

---

## Overview

This module installs and configures:

| Component | Purpose |
|-----------|---------|
| **Ollama** | Local LLM inference engine (llama.cpp backend) |
| **Open WebUI** | Browser-based ChatGPT-style interface |
| **NVIDIA CUDA** | GPU-accelerated inference |
| **PyTorch** | Deep learning framework with CUDA support |
| **Jupyter Lab** | Interactive notebook environment |
| **LangChain** | RAG and AI agent framework |

**Perfect for:**
- Offline AI assistants (your own Jarvis)
- Privacy-focused LLM usage
- Coding assistants (Copilot alternatives)
- Robotics vision and NLP systems
- RAG over local documents

---

## Prerequisites

- Lenovo ThinkPad P-Series (or any NVIDIA-equipped workstation)
- Pop!\_OS 22.04 LTS (NVIDIA ISO recommended)
- NVIDIA GPU with CUDA support (RTX A1000 6 GB on reference machine)
- At least 16 GB RAM (32 GB DDR5 on reference machine)
- 50 GB+ free disk space (for models)

Verify your GPU and driver:

```bash
nvidia-smi          # Should show your GPU and driver version
nvcc --version      # CUDA compiler (install via scripts/ai-setup.sh)
```

---

## Quick Setup (Script)

The interactive script handles everything automatically:

```bash
cd pop-os-linux-optimisation
chmod +x scripts/ai-setup.sh
./scripts/ai-setup.sh
```

Or from the master installer:

```bash
./install.sh --ai
```

---

## Ollama — Local LLM Engine

[Ollama](https://ollama.com/) wraps llama.cpp with a simple CLI and serves models via a local REST API.

### Install

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Verify Installation

```bash
ollama --version
systemctl status ollama    # Should be active (running)
```

### Run Your First Model

```bash
ollama run phi3            # Lightweight, fast — great for 6GB VRAM
```

### Manage Models

```bash
ollama list                # List downloaded models
ollama pull mistral        # Download a model
ollama rm codellama        # Remove a model
ollama show phi3           # Show model details
```

---

## Model Recommendations by GPU

### RTX A1000 6 GB VRAM (Entry Tier)

With 6 GB VRAM, use **quantized models** (Q4_K_M or Q4_0) for best performance. Larger models will partially offload to CPU/RAM.

| Model | Parameters | VRAM Usage | Command | Best For |
|-------|-----------|-----------|---------|----------|
| **Phi-3 Mini** | 3.8B | ~3.5 GB | `ollama run phi3` | General AI, fast responses |
| **Llama 3.2** | 3B | ~2.5 GB | `ollama run llama3.2:3b` | Conversational AI |
| **TinyLlama** | 1.1B | ~1.5 GB | `ollama run tinyllama` | Fastest, embedded tasks |
| **Mistral 7B** | 7B (Q4) | ~5 GB | `ollama run mistral` | Coding, reasoning |
| **CodeLlama 7B** | 7B (Q4) | ~5 GB | `ollama run codellama` | Code generation |
| **Gemma 2B** | 2B | ~2 GB | `ollama run gemma:2b` | Lightweight general |

> **Tip:** Models marked Q4 are 4-bit quantized. They use less VRAM with minimal quality loss.

### 8 GB VRAM (Medium Tier)

| Model | Command | Notes |
|-------|---------|-------|
| Llama 3.1 8B | `ollama run llama3.1` | Best general-purpose |
| Gemma 2 9B | `ollama run gemma2` | Strong reasoning |
| Mistral 7B | `ollama run mistral` | Fast coding assistant |
| DeepSeek Coder V2 | `ollama run deepseek-coder-v2` | Programming specialist |

### 16+ GB VRAM (High Tier)

| Model | Command | Notes |
|-------|---------|-------|
| Llama 3.1 8B | `ollama run llama3.1` | Plenty of headroom |
| CodeLlama 13B | `ollama run codellama:13b` | Large code model |
| Mixtral 8x7B | `ollama run mixtral` | Mixture of experts |

---

## Open WebUI — ChatGPT-Style Interface

[Open WebUI](https://github.com/open-webui/open-webui) provides a browser-based interface identical to ChatGPT, connected to your local Ollama instance.

### Prerequisites

- Docker installed and running
- Ollama running on `localhost:11434`

### Deploy

```bash
docker run -d \
    --name open-webui \
    --restart unless-stopped \
    -p 3000:8080 \
    -v open-webui-data:/app/backend/data \
    --add-host=host.docker.internal:host-gateway \
    ghcr.io/open-webui/open-webui:main
```

### Access

Open **http://localhost:3000** in your browser.

- First visit: create an admin account
- It auto-discovers Ollama models on `localhost:11434`
- Supports multi-model conversations, file uploads, and RAG

### Management

```bash
docker logs -f open-webui     # View logs
docker restart open-webui     # Restart
docker stop open-webui        # Stop
docker start open-webui       # Start again
```

---

## Python ML Stack

A dedicated virtual environment keeps ML dependencies isolated:

```bash
# Create environment
python3 -m venv ~/.venvs/ml
source ~/.venvs/ml/bin/activate

# Install PyTorch with CUDA 12.1
pip install torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu121

# Install Hugging Face ecosystem
pip install transformers accelerate datasets \
    sentencepiece tokenizers safetensors \
    bitsandbytes huggingface-hub evaluate
```

### Verify CUDA in PyTorch

```python
import torch
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"GPU: {torch.cuda.get_device_name(0)}")
print(f"VRAM: {torch.cuda.get_device_properties(0).total_mem / 1e9:.1f} GB")
```

---

## Jupyter Lab

```bash
source ~/.venvs/ml/bin/activate
pip install jupyterlab ipykernel ipywidgets

# Register the ML kernel
python -m ipykernel install --user --name ml --display-name "Python (ML)"

# Launch
jupyter lab
```

Access at **http://localhost:8888**.

---

## API Access from Python

Ollama exposes a REST API on `localhost:11434`. Use it from any Python project:

### Simple Generation

```python
import requests

response = requests.post(
    "http://localhost:11434/api/generate",
    json={
        "model": "phi3",
        "prompt": "Explain SLAM in robotics simply",
        "stream": False,
    }
)

print(response.json()["response"])
```

### Streaming Responses

```python
import requests
import json

response = requests.post(
    "http://localhost:11434/api/generate",
    json={"model": "phi3", "prompt": "Write a Python function for binary search"},
    stream=True,
)

for line in response.iter_lines():
    if line:
        data = json.loads(line)
        print(data.get("response", ""), end="", flush=True)
```

### Chat API (Multi-Turn)

```python
import requests

response = requests.post(
    "http://localhost:11434/api/chat",
    json={
        "model": "phi3",
        "messages": [
            {"role": "system", "content": "You are a robotics assistant."},
            {"role": "user", "content": "How does a LiDAR sensor work?"},
        ],
        "stream": False,
    }
)

print(response.json()["message"]["content"])
```

---

## LangChain & RAG

Build a retrieval-augmented generation pipeline over your local documents:

```bash
source ~/.venvs/ml/bin/activate
pip install langchain langchain-community chromadb \
    sentence-transformers faiss-cpu unstructured pymupdf
```

### Example: Chat Over PDF

```python
from langchain_community.llms import Ollama
from langchain_community.embeddings import OllamaEmbeddings
from langchain_community.vectorstores import Chroma
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.chains import RetrievalQA
from langchain_community.document_loaders import PyMuPDFLoader

# Load document
loader = PyMuPDFLoader("your_document.pdf")
docs = loader.load()

# Split into chunks
splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
chunks = splitter.split_documents(docs)

# Create vector store
embeddings = OllamaEmbeddings(model="phi3")
vectorstore = Chroma.from_documents(chunks, embeddings)

# Create QA chain
llm = Ollama(model="phi3")
qa = RetrievalQA.from_chain_type(
    llm=llm,
    retriever=vectorstore.as_retriever(),
)

# Ask questions
answer = qa.invoke("Summarize the main findings")
print(answer["result"])
```

---

## Troubleshooting

### Ollama won't start

```bash
sudo systemctl status ollama    # Check service status
journalctl -u ollama -f         # View logs
ollama serve                    # Run manually for debug output
```

### CUDA not detected

```bash
nvidia-smi                      # Verify driver
nvcc --version                  # Verify CUDA toolkit
python3 -c "import torch; print(torch.cuda.is_available())"
```

If CUDA isn't found, install via:

```bash
sudo apt install nvidia-cuda-toolkit
```

### Out of VRAM

- Use a smaller model (phi3, tinyllama, gemma:2b)
- Use quantized variants (models ending in Q4_K_M)
- Close other GPU applications (browsers using hardware acceleration, etc.)

### Open WebUI can't connect to Ollama

```bash
# Ensure Ollama is listening on all interfaces
sudo systemctl edit ollama
# Add: Environment="OLLAMA_HOST=0.0.0.0"
sudo systemctl restart ollama
```

---

## Further Reading

- [Ollama Documentation](https://github.com/ollama/ollama)
- [Open WebUI Documentation](https://docs.openwebui.com/)
- [PyTorch CUDA Guide](https://pytorch.org/get-started/locally/)
- [Hugging Face Model Hub](https://huggingface.co/models)
- [LangChain Documentation](https://python.langchain.com/)