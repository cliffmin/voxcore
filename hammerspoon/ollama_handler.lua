-- Ollama/LLM Handler for PTT Dictation
-- Provides graceful fallback when Ollama isn't available

local M = {}

-- Configuration
M.config = {
    ollama_url = "http://127.0.0.1:11434",
    check_timeout = 2,  -- seconds to wait for Ollama health check
    notification_duration = 5,
    auto_start_ollama = true,  -- attempt to start Ollama if not running
    show_user_prompts = true,
    fallback_to_basic = true  -- use basic processing if Ollama unavailable
}

-- Cache Ollama status to avoid repeated checks
local ollama_status = {
    available = nil,
    last_check = 0,
    check_interval = 60  -- recheck every 60 seconds
}

-- Check if Ollama is running
function M.is_ollama_available()
    local current_time = os.time()
    
    -- Use cached result if recent
    if ollama_status.available ~= nil and 
       (current_time - ollama_status.last_check) < ollama_status.check_interval then
        return ollama_status.available
    end
    
    -- Perform health check
    local handle = io.popen(string.format(
        'curl -s -m %d %s/api/tags 2>/dev/null | head -c 1',
        M.config.check_timeout,
        M.config.ollama_url
    ))
    
    if handle then
        local result = handle:read("*a")
        handle:close()
        
        ollama_status.available = (result ~= "")
        ollama_status.last_check = current_time
        
        return ollama_status.available
    end
    
    return false
end

-- Attempt to start Ollama
function M.start_ollama()
    print("Attempting to start Ollama...")
    
    -- Check if Docker is running first
    local docker_check = io.popen("docker info >/dev/null 2>&1 && echo 'running'")
    if docker_check then
        local docker_status = docker_check:read("*a")
        docker_check:close()
        
        if docker_status:match("running") then
            -- Try to start existing Ollama container
            os.execute("docker start ollama >/dev/null 2>&1")
            
            -- Wait a moment for it to start
            hs.timer.usleep(2000000)  -- 2 seconds
            
            -- Check if it's now available
            if M.is_ollama_available() then
                hs.notify.new({
                    title = "Ollama Started",
                    informativeText = "LLM refinement is now available",
                    soundName = "Glass"
                }):send()
                return true
            end
        else
            -- Docker isn't running - try OrbStack
            os.execute("open -a OrbStack >/dev/null 2>&1")
            hs.timer.usleep(3000000)  -- 3 seconds for OrbStack to start
            
            -- Try again after OrbStack starts
            os.execute("docker start ollama >/dev/null 2>&1")
            hs.timer.usleep(2000000)
            
            return M.is_ollama_available()
        end
    end
    
    return false
end

-- Handle long recordings with graceful fallback
function M.handle_long_recording(duration, text, callback)
    local ollama_available = M.is_ollama_available()
    
    if duration > 21 then
        if ollama_available then
            -- Use VoxCompose with LLM refinement
            print("Using VoxCompose with LLM refinement for long recording")
            return {
                processor = "voxcompose",
                use_llm = true,
                model = "llama3.2:1b"
            }
        else
            -- Ollama not available - provide options to user
            local choices = {}
            
            -- Option 1: Try to start Ollama
            if M.config.auto_start_ollama then
                table.insert(choices, {
                    text = "Start Ollama and use AI refinement",
                    action = function()
                        if M.start_ollama() then
                            callback({processor = "voxcompose", use_llm = true})
                        else
                            M.show_ollama_setup_guide()
                            callback({processor = "voxcompose", use_llm = false})
                        end
                    end
                })
            end
            
            -- Option 2: Use VoxCompose without LLM
            table.insert(choices, {
                text = "Use basic corrections only (faster)",
                action = function()
                    callback({processor = "voxcompose", use_llm = false})
                end
            })
            
            -- Option 3: Use standard whisper processing
            table.insert(choices, {
                text = "Use standard processing",
                action = function()
                    callback({processor = "whisper", use_llm = false})
                end
            })
            
            -- Show chooser to user
            if M.config.show_user_prompts then
                local chooser = hs.chooser.new(function(choice)
                    if choice then
                        choice.action()
                    else
                        -- User cancelled - use fallback
                        callback({processor = "voxcompose", use_llm = false})
                    end
                end)
                
                chooser:choices(choices)
                chooser:placeholderText("Ollama not available. Choose processing method:")
                chooser:show()
            else
                -- Auto-fallback without prompting
                if M.config.fallback_to_basic then
                    print("Ollama unavailable - using basic VoxCompose corrections")
                    return {processor = "voxcompose", use_llm = false}
                else
                    return {processor = "whisper", use_llm = false}
                end
            end
        end
    else
        -- Short recording - use standard processing
        return {processor = "whisper", use_llm = false}
    end
end

-- Show setup guide for Ollama
function M.show_ollama_setup_guide()
    local message = [[
Ollama is not available for AI refinement.

To enable AI refinement for long recordings:

1. Install Docker Desktop or OrbStack
2. Run: docker run -d --name ollama -p 11434:11434 ollama/ollama
3. Pull a model: docker exec ollama ollama pull llama3.2:1b

Or disable AI refinement in settings.]]
    
    hs.notify.new({
        title = "Ollama Setup Required",
        informativeText = message,
        hasActionButton = true,
        actionButtonTitle = "Open Guide",
        withdrawAfter = 0  -- Don't auto-dismiss
    }):send()
end

-- Monitor Ollama status periodically
function M.start_monitoring()
    hs.timer.doEvery(300, function()  -- Check every 5 minutes
        local was_available = ollama_status.available
        local is_available = M.is_ollama_available()
        
        -- Notify user if status changed
        if was_available == true and is_available == false then
            hs.notify.new({
                title = "Ollama Disconnected",
                informativeText = "AI refinement unavailable. Using basic corrections.",
                soundName = "Basso"
            }):send()
        elseif was_available == false and is_available == true then
            hs.notify.new({
                title = "Ollama Connected",
                informativeText = "AI refinement is now available",
                soundName = "Glass"
            }):send()
        end
    end)
end

-- Integration point for push_to_talk.lua
function M.process_with_best_available(text, duration)
    local processing_config = M.handle_long_recording(duration, text, function(config)
        return config
    end)
    
    -- Log the decision
    print(string.format(
        "Recording duration: %.1fs, Processor: %s, LLM: %s",
        duration,
        processing_config.processor,
        processing_config.use_llm and "enabled" or "disabled"
    ))
    
    return processing_config
end

-- Initialize
function M.init()
    -- Check Ollama status on startup
    M.is_ollama_available()
    
    -- Start monitoring if configured
    if M.config.show_user_prompts then
        M.start_monitoring()
    end
end

return M