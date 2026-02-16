-- Script de Auto-Navegação para Models "Lid"
-- Criado com UI simples e movimento suave

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- Variáveis de controle
local isRunning = false
local currentCoroutine = nil
local godmodeEnabled = false
local godmodeConnection = nil
local autoServerHop = true -- Ativa server hop automático por padrão
local antiVoidConnection = nil
local autoClickerEnabled = false -- Auto clicker desativado por padrão

-- Função para encontrar todos os models "Lid" no workspace
local function findAllLids()
    local lids = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "Lid" then
            table.insert(lids, obj)
        end
    end
    return lids
end

-- Função para desativar colisões (noclip)
local function enableNoclip()
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

-- Função para reativar colisões
local function disableNoclip()
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = true
        end
    end
end

-- Função para ativar godmode
local function enableGodmode()
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    godmodeEnabled = true
    
    -- Mantém a vida no máximo
    humanoid.MaxHealth = math.huge
    humanoid.Health = math.huge
    
    -- Monitora mudanças na vida
    godmodeConnection = humanoid.HealthChanged:Connect(function(health)
        if godmodeEnabled and health < humanoid.MaxHealth then
            humanoid.Health = humanoid.MaxHealth
        end
    end)
    
    print("Godmode ativado!")
end

-- Função para desativar godmode
local function disableGodmode()
    godmodeEnabled = false
    
    if godmodeConnection then
        godmodeConnection:Disconnect()
        godmodeConnection = nil
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.MaxHealth = 100
        humanoid.Health = 100
    end
    
    print("Godmode desativado!")
end

-- Função para trocar de servidor
local function serverHop()
    print("Procurando outro servidor...")
    
    local success, result = pcall(function()
        local servers = {}
        local cursor = ""
        
        -- Busca servidores disponíveis
        repeat
            local success, page = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(
                    "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100" .. 
                    (cursor and "&cursor=" .. cursor or "")
                ))
            end)
            
            if success and page then
                for _, server in pairs(page.data) do
                    if server.playing < server.maxPlayers and server.id ~= game.JobId then
                        table.insert(servers, server.id)
                    end
                end
                cursor = page.nextPageCursor
            else
                break
            end
        until not cursor
        
        -- Teleporta para um servidor aleatório
        if #servers > 0 then
            local randomServer = servers[math.random(1, #servers)]
            print("Teleportando para novo servidor...")
            TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer, player)
        else
            -- Se não encontrar servidores, apenas teleporta para qualquer servidor
            print("Teleportando para qualquer servidor disponível...")
            TeleportService:Teleport(game.PlaceId, player)
        end
    end)
    
    if not success then
        warn("Erro ao trocar de servidor: " .. tostring(result))
        -- Tenta teleporte simples como fallback
        pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
        end)
    end
end

-- Sistema Anti-Void (sempre ativo)
local function setupAntiVoid()
    -- Monitora a altura do personagem
    antiVoidConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if not humanoidRootPart or not humanoidRootPart.Parent then
            return
        end
        
        local currentPosition = humanoidRootPart.Position
        
        -- Se cair abaixo de -100 (void), teleporta para o Lid mais próximo
        if currentPosition.Y < -100 then
            local humanoid = character:FindFirstChild("Humanoid")
            
            -- Busca o Lid mais próximo
            local nearestLid = nil
            local nearestDistance = math.huge
            
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("Model") and obj.Name == "Lid" then
                    local lidPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if lidPart then
                        local distance = (lidPart.Position - Vector3.new(currentPosition.X, 0, currentPosition.Z)).Magnitude
                        if distance < nearestDistance then
                            nearestDistance = distance
                            nearestLid = lidPart
                        end
                    end
                end
            end
            
            -- Teleporta para o Lid mais próximo ou para cima se não encontrar
            if nearestLid then
                humanoidRootPart.CFrame = CFrame.new(nearestLid.Position + Vector3.new(0, 5, 0))
                print("Anti-Void: Teleportado para Lid mais próximo!")
            else
                -- Se não encontrar Lid, teleporta para cima
                local newPosition = Vector3.new(currentPosition.X, currentPosition.Y + 250, currentPosition.Z)
                humanoidRootPart.CFrame = CFrame.new(newPosition)
                print("Anti-Void: Teleportado para cima (nenhum Lid encontrado)!")
            end
            
            humanoidRootPart.Velocity = Vector3.new(0, 0, 0)
            humanoidRootPart.RotVelocity = Vector3.new(0, 0, 0)
            
            -- Reseta o estado do humanoid para destravar
            if humanoid then
                humanoid.PlatformStand = false
                humanoid.Sit = false
                humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
            end
            
            -- Reativa colisões
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end)
    
    print("Anti-Void ativado automaticamente!")
end

-- Função para pressionar a tecla F
local function pressF()
    local VirtualInputManager = game:GetService("VirtualInputManager")
    
    -- Pressiona F
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
    print("Segurando F por 4 segundos...")
    wait(4) -- Segura por 4 segundos
    -- Solta F
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    print("F solto!")
end

-- Função para teleporte instantâneo silencioso
local function silentTeleport(targetPosition)
    -- Desativa física temporariamente
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.PlatformStand = true
    end
    
    -- Desativa colisões
    enableNoclip()
    
    -- Teleporta instantaneamente
    humanoidRootPart.CFrame = CFrame.new(targetPosition + Vector3.new(0, 3, 0)) -- Um pouco acima
    humanoidRootPart.Velocity = Vector3.new(0, 0, 0)
    humanoidRootPart.RotVelocity = Vector3.new(0, 0, 0)
    
    wait(0.1)
    
    -- Reativa física
    if humanoid then
        humanoid.PlatformStand = false
    end
end

-- Função principal de navegação
local function startNavigation()
    isRunning = true
    
    currentCoroutine = coroutine.create(function()
        local lids = findAllLids()
        
        if #lids == 0 then
            warn("Nenhum model 'Lid' encontrado!")
            isRunning = false
            return
        end
        
        print("Encontrados " .. #lids .. " models 'Lid'. Iniciando navegação...")
        
        for i, lid in ipairs(lids) do
            if not isRunning then
                print("Navegação interrompida!")
                break
            end
            
            -- Pega a posição do Lid (usa PrimaryPart ou primeira Part)
            local targetPart = lid.PrimaryPart or lid:FindFirstChildWhichIsA("BasePart")
            
            if targetPart then
                local targetPosition = targetPart.Position
                print("Indo para Lid " .. i .. " de " .. #lids)
                
                -- Teleporte silencioso e instantâneo
                silentTeleport(targetPosition)
                
                -- Pressiona F se auto clicker estiver ativado
                if autoClickerEnabled then
                    wait(0.2) -- Pequena espera após teleporte
                    pressF()
                    print("Pressionado F no Lid " .. i)
                end
                
                -- Espera 7 segundos antes de ir para o próximo
                if isRunning and i < #lids then
                    print("Aguardando 7 segundos...")
                    wait(4)
                end
            else
                warn("Lid " .. i .. " não possui partes válidas!")
            end
        end
        
        if isRunning then
            print("Navegação concluída! Todos os Lids foram visitados.")
            
            -- Server hop automático se habilitado
            if autoServerHop then
                print("Aguardando 3 segundos antes de trocar de servidor...")
                wait(1)
                serverHop()
            end
        end
        
        isRunning = false
    end)
    
    coroutine.resume(currentCoroutine)
end

-- Função para parar a navegação
local function stopNavigation()
    isRunning = false
    if currentCoroutine then
        currentCoroutine = nil
    end
    
    -- Reativa colisões ao parar
    disableNoclip()
    
    print("Navegação parada!")
end

-- Criação da UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LidNavigatorUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Frame principal
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 200, 0, 225)
mainFrame.Position = UDim2.new(0.5, -100, 0.5, -112)
mainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
mainFrame.BorderSizePixel = 2
mainFrame.BorderColor3 = Color3.fromRGB(0, 170, 255)
mainFrame.Parent = screenGui

-- Arredondamento do frame
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

-- Título
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
title.BorderSizePixel = 0
title.Text = "Farm Chest"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = title

-- Botão Iniciar
local startButton = Instance.new("TextButton")
startButton.Size = UDim2.new(0, 160, 0, 30)
startButton.Position = UDim2.new(0.5, -80, 0, 45)
startButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
startButton.Text = "▶ Play"
startButton.TextColor3 = Color3.fromRGB(255, 255, 255)
startButton.TextSize = 14
startButton.Font = Enum.Font.GothamBold
startButton.BorderSizePixel = 0
startButton.Parent = mainFrame

local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 6)
startCorner.Parent = startButton

-- Botão Parar
local stopButton = Instance.new("TextButton")
stopButton.Size = UDim2.new(0, 160, 0, 30)
stopButton.Position = UDim2.new(0.5, -80, 0, 80)
stopButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
stopButton.Text = "■ Stop"
stopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
stopButton.TextSize = 14
stopButton.Font = Enum.Font.GothamBold
stopButton.BorderSizePixel = 0
stopButton.Parent = mainFrame

local stopCorner = Instance.new("UICorner")
stopCorner.CornerRadius = UDim.new(0, 6)
stopCorner.Parent = stopButton

-- Botão Godmode
local godmodeButton = Instance.new("TextButton")
godmodeButton.Size = UDim2.new(0, 160, 0, 30)
godmodeButton.Position = UDim2.new(0.5, -80, 0, 115)
godmodeButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
godmodeButton.Text = "🛡️ Godmode: OFF"
godmodeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
godmodeButton.TextSize = 14
godmodeButton.Font = Enum.Font.GothamBold
godmodeButton.BorderSizePixel = 0
godmodeButton.Parent = mainFrame

local godmodeCorner = Instance.new("UICorner")
godmodeCorner.CornerRadius = UDim.new(0, 6)
godmodeCorner.Parent = godmodeButton

-- Botão Server Hop
local serverHopButton = Instance.new("TextButton")
serverHopButton.Size = UDim2.new(0, 160, 0, 30)
serverHopButton.Position = UDim2.new(0.5, -80, 0, 150)
serverHopButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
serverHopButton.Text = "🌐 Auto Server Hop: ON"
serverHopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
serverHopButton.TextSize = 13
serverHopButton.Font = Enum.Font.GothamBold
serverHopButton.BorderSizePixel = 0
serverHopButton.Parent = mainFrame

local serverHopCorner = Instance.new("UICorner")
serverHopCorner.CornerRadius = UDim.new(0, 6)
serverHopCorner.Parent = serverHopButton

-- Botão Auto Clicker
local autoClickerButton = Instance.new("TextButton")
autoClickerButton.Size = UDim2.new(0, 160, 0, 30)
autoClickerButton.Position = UDim2.new(0.5, -80, 0, 185)
autoClickerButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
autoClickerButton.Text = "⌨️ Auto Press F: OFF"
autoClickerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
autoClickerButton.TextSize = 13
autoClickerButton.Font = Enum.Font.GothamBold
autoClickerButton.BorderSizePixel = 0
autoClickerButton.Parent = mainFrame

local autoClickerCorner = Instance.new("UICorner")
autoClickerCorner.CornerRadius = UDim.new(0, 6)
autoClickerCorner.Parent = autoClickerButton

-- Tornar o frame arrastável
local dragging = false
local dragInput, mousePos, framePos

mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        mousePos = input.Position
        framePos = mainFrame.Position
    end
end)

mainFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - mousePos
        mainFrame.Position = UDim2.new(
            framePos.X.Scale,
            framePos.X.Offset + delta.X,
            framePos.Y.Scale,
            framePos.Y.Offset + delta.Y
        )
    end
end)

-- Eventos dos botões
startButton.MouseButton1Click:Connect(function()
    if not isRunning then
        -- Atualiza o character caso tenha respawnado
        character = player.Character or player.CharacterAdded:Wait()
        humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        
        startNavigation()
        startButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        stopButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    else
        warn("Navegação já está em andamento!")
    end
end)

stopButton.MouseButton1Click:Connect(function()
    if isRunning then
        stopNavigation()
        startButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
        stopButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    end
end)

-- Efeitos hover nos botões
startButton.MouseEnter:Connect(function()
    if not isRunning then
        startButton.BackgroundColor3 = Color3.fromRGB(0, 220, 0)
    end
end)

startButton.MouseLeave:Connect(function()
    if not isRunning then
        startButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
    end
end)

stopButton.MouseEnter:Connect(function()
    stopButton.BackgroundColor3 = Color3.fromRGB(220, 0, 0)
end)

stopButton.MouseLeave:Connect(function()
    if isRunning then
        stopButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    else
        stopButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    end
end)

-- Evento do botão Godmode
godmodeButton.MouseButton1Click:Connect(function()
    -- Atualiza o character caso tenha respawnado
    character = player.Character or player.CharacterAdded:Wait()
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    if not godmodeEnabled then
        enableGodmode()
        godmodeButton.Text = "🛡️ Godmode: ON"
        godmodeButton.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    else
        disableGodmode()
        godmodeButton.Text = "🛡️ Godmode: OFF"
        godmodeButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    end
end)

-- Efeito hover no botão Godmode
godmodeButton.MouseEnter:Connect(function()
    if godmodeEnabled then
        godmodeButton.BackgroundColor3 = Color3.fromRGB(255, 235, 50)
    else
        godmodeButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    end
end)

godmodeButton.MouseLeave:Connect(function()
    if godmodeEnabled then
        godmodeButton.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    else
        godmodeButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    end
end)

-- Evento do botão Server Hop
serverHopButton.MouseButton1Click:Connect(function()
    autoServerHop = not autoServerHop
    
    if autoServerHop then
        serverHopButton.Text = "🌐 Auto Server Hop: ON"
        serverHopButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    else
        serverHopButton.Text = "🌐 Auto Server Hop: OFF"
        serverHopButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    end
end)

-- Efeito hover no botão Server Hop
serverHopButton.MouseEnter:Connect(function()
    if autoServerHop then
        serverHopButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    else
        serverHopButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    end
end)

serverHopButton.MouseLeave:Connect(function()
    if autoServerHop then
        serverHopButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    else
        serverHopButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    end
end)

-- Evento do botão Auto Clicker
autoClickerButton.MouseButton1Click:Connect(function()
    autoClickerEnabled = not autoClickerEnabled
    
    if autoClickerEnabled then
        autoClickerButton.Text = "⌨️ Auto Press F: ON"
        autoClickerButton.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    else
        autoClickerButton.Text = "⌨️ Auto Press F: OFF"
        autoClickerButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    end
end)

-- Efeito hover no botão Auto Clicker
autoClickerButton.MouseEnter:Connect(function()
    if autoClickerEnabled then
        autoClickerButton.BackgroundColor3 = Color3.fromRGB(158, 63, 246)
    else
        autoClickerButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    end
end)

autoClickerButton.MouseLeave:Connect(function()
    if autoClickerEnabled then
        autoClickerButton.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    else
        autoClickerButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    end
end)

-- Ativa o Anti-Void automaticamente
setupAntiVoid()

-- Reativa o Anti-Void se o personagem respawnar
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Desconecta o antigo
    if antiVoidConnection then
        antiVoidConnection:Disconnect()
    end
    
    -- Reconecta o anti-void
    wait(1) -- Espera o character carregar completamente
    setupAntiVoid()
end)

print("Script Lid Navigator carregado! UI criada com sucesso.")
