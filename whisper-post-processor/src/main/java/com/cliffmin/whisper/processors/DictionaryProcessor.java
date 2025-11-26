package com.cliffmin.whisper.processors;

import com.cliffmin.whisper.pipeline.TextProcessor;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * Applies dictionary-based word replacements for common tech terms.
 * 
 * This processor handles proper capitalization of technical terminology
 * that Whisper often outputs in lowercase. For user-specific customization
 * and learned corrections, use VoxCompose plugin.
 */
public class DictionaryProcessor implements TextProcessor {
    
    private final Map<String, String> replacements;
    
    public DictionaryProcessor() {
        this.replacements = defaultReplacements();
    }
    
    public DictionaryProcessor(Map<String, String> replacements) {
        this.replacements = replacements != null ? replacements : new HashMap<>();
    }
    
    @Override
    public String process(String input) {
        if (input == null || input.isEmpty() || replacements.isEmpty()) {
            return input;
        }
        
        String result = input;
        
        for (Map.Entry<String, String> entry : replacements.entrySet()) {
            String pattern = entry.getKey();
            String replacement = entry.getValue();
            
            // Create word boundary pattern (case-insensitive)
            String regex = "\\b" + Pattern.quote(pattern) + "\\b";
            Pattern p = Pattern.compile(regex, Pattern.CASE_INSENSITIVE);
            
            result = p.matcher(result).replaceAll(replacement);
        }
        
        return result;
    }
    
    private Map<String, String> defaultReplacements() {
        Map<String, String> m = new HashMap<>();
        // Common tech terms - proper capitalization
        m.put("github", "GitHub");
        m.put("javascript", "JavaScript");
        m.put("typescript", "TypeScript");
        m.put("nodejs", "Node.js");
        m.put("node.js", "Node.js");
        m.put("json", "JSON");
        m.put("xml", "XML");
        m.put("html", "HTML");
        m.put("css", "CSS");
        m.put("api", "API");
        m.put("apis", "APIs");
        m.put("rest", "REST");
        m.put("graphql", "GraphQL");
        m.put("sql", "SQL");
        m.put("nosql", "NoSQL");
        m.put("python", "Python");
        m.put("golang", "Go");
        m.put("kotlin", "Kotlin");
        m.put("rust", "Rust");
        m.put("java", "Java");
        m.put("aws", "AWS");
        m.put("gcp", "GCP");
        m.put("azure", "Azure");
        m.put("docker", "Docker");
        m.put("kubernetes", "Kubernetes");
        m.put("k8s", "K8s");
        m.put("ios", "iOS");
        m.put("macos", "macOS");
        m.put("linux", "Linux");
        m.put("windows", "Windows");
        m.put("postgresql", "PostgreSQL");
        m.put("postgres", "Postgres");
        m.put("mongodb", "MongoDB");
        m.put("redis", "Redis");
        m.put("elasticsearch", "Elasticsearch");
        m.put("npm", "npm");
        m.put("yarn", "Yarn");
        m.put("webpack", "Webpack");
        m.put("vite", "Vite");
        m.put("react", "React");
        m.put("vue", "Vue");
        m.put("angular", "Angular");
        m.put("svelte", "Svelte");
        m.put("nextjs", "Next.js");
        m.put("next.js", "Next.js");
        m.put("nuxt", "Nuxt");
        m.put("springboot", "Spring Boot");
        m.put("spring boot", "Spring Boot");
        m.put("django", "Django");
        m.put("flask", "Flask");
        m.put("fastapi", "FastAPI");
        m.put("oauth", "OAuth");
        m.put("jwt", "JWT");
        m.put("http", "HTTP");
        m.put("https", "HTTPS");
        m.put("url", "URL");
        m.put("urls", "URLs");
        m.put("uri", "URI");
        m.put("uuid", "UUID");
        m.put("id", "ID");
        m.put("ids", "IDs");
        m.put("cpu", "CPU");
        m.put("gpu", "GPU");
        m.put("ram", "RAM");
        m.put("ssd", "SSD");
        m.put("ci", "CI");
        m.put("cd", "CD");
        m.put("cicd", "CI/CD");
        m.put("ci/cd", "CI/CD");
        m.put("devops", "DevOps");
        m.put("sre", "SRE");
        m.put("cli", "CLI");
        m.put("gui", "GUI");
        m.put("ui", "UI");
        m.put("ux", "UX");
        m.put("ai", "AI");
        m.put("ml", "ML");
        m.put("llm", "LLM");
        m.put("llms", "LLMs");
        m.put("gpt", "GPT");
        m.put("chatgpt", "ChatGPT");
        m.put("openai", "OpenAI");
        m.put("anthropic", "Anthropic");
        m.put("claude", "Claude");
        m.put("ollama", "Ollama");
        m.put("langchain", "LangChain");
        m.put("salesforce", "Salesforce");
        m.put("jira", "Jira");
        m.put("slack", "Slack");
        m.put("notion", "Notion");
        m.put("figma", "Figma");
        m.put("vs code", "VS Code");
        m.put("vscode", "VS Code");
        m.put("intellij", "IntelliJ");
        m.put("xcode", "Xcode");
        m.put("git", "Git");
        m.put("gitlab", "GitLab");
        m.put("bitbucket", "Bitbucket");
        return m;
    }
    
    @Override
    public int getPriority() {
        return 35; // Run after structural processors but before final cleanup
    }
}
