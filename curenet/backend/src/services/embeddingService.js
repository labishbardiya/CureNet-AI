const axios = require('axios');
require('dotenv').config();

/**
 * Generates a vector embedding for a piece of clinical text.
 * This enables "Semantically Similar" record search (e.g. finding 
 * all records related to 'Hypertension' even if the word isn't used).
 */
exports.generateEmbedding = async (text) => {
    try {
        // PRODUCTION PATH 1: NVIDIA NIM (High performance, medical-grade)
        const nvidiaKey = process.env.NVIDIA_EMBEDDING_KEY || process.env.NVIDIA_API_KEY;
        if (nvidiaKey) {
            const response = await axios.post('https://integrate.api.nvidia.com/v1/embeddings', {
                input: [text],
                model: "nvidia/nv-embedqa-e5-v5",
                input_type: "query",
                encoding_format: "float"
            }, { 
                headers: { 
                    Authorization: `Bearer ${nvidiaKey}`,
                    "Accept": "application/json"
                } 
            });
            return response.data.data[0].embedding;
        }

        // PRODUCTION PATH 2: OpenAI or Gemini Embeddings
        if (process.env.OPENAI_API_KEY) {
            const response = await axios.post('https://api.openai.com/v1/embeddings', {
                input: text,
                model: "text-embedding-3-small"
            }, { headers: { Authorization: `Bearer ${process.env.OPENAI_API_KEY}` } });
            return response.data.data[0].embedding;
        }

        // DEMO PATH: Generating a high-entropy pseudo-vector for demo Atlas integration
        // In a real environment, this would be a 1024-dim float array from an LLM.
        const hash = Buffer.from(text).reduce((acc, char) => acc + char, 0);
        const vector = new Array(1024).fill(0).map((_, i) => {
            return Math.sin(hash + i) * Math.cos(hash * i);
        });
        
        return vector;
    } catch (err) {
        console.error('[EmbeddingService] Failed to generate vector:', err.message);
        return new Array(1024).fill(0);
    }
};
