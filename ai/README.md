### AI Workstation mode
### This converts your laptop into a local ChatGPT-style machine.

### **Perfect for**:
- Offline AI
- Privacy
- Coding assistants
- Your Jarvis project

### Option A - Using Ollama
- Step 1. Install Ollama
```
curl -fsSL https://ollama.com/install.sh | sh
```

- Step 2. Run your first local LLM
```
ollama run llama3
```

### Model based on GPUs
### ***RTX A1000 6GB***
| Model      | Command                | Use         |
| ---------- | ---------------------- | ----------- |
| Llama 3 8B | `ollama run llama3`    | General AI  |
| Mistral    | `ollama run mistral`   | Fast coding |
| Phi-3      | `ollama run phi3`      | Lightweight |
| Code LLM   | `ollama run codellama` | Programming |

- step 3. Web UI usage like chatgpt
```
docker run -d -p 3000:8080 \
-v ollama:/root/.ollama \
ghcr.io/open-webui/open-webui:main
```

- Step 4. Then open it at ***`http://localhost:3000`***

- Step 5. Optional
Use with python requests for your projects.
```
import requests

response = requests.post(
    "http://localhost:11434/api/generate",
    json={"model": "llama3", "prompt": "Explain robotics SLAM simply"}
)

print(response.json()["response"])
```

Perfect for:
- creating your own AI assistant
- Robotics vision systems
- Translation models