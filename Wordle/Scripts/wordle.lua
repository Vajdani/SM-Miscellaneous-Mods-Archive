Wordle = class()

dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"

local words = {
    "charm", "raise", "eject", "metal", "lobby", "fight", "mayor", "blast", "twist", "trait", "panel", "feign", "split", "tense", "round", "exile",
    "model", "reign", "thank", "major", "place", "allow", "sweep", "giant", "blame", "bless", "smile", "break", "truth", "muggy", "radio", "attic",
    "handy", "rugby", "opera", "force", "strap", "fault", "order", "elect", "berry", "tasty", "count", "prove", "irony", "trend", "drill", "climb",
    "glide", "steam", "ideal", "creed", "jewel", "still", "adult", "swarm", "shave", "rough", "cruel", "drama", "sniff", "stamp", "award", "chord",
    "light", "queen", "shelf", "burst", "trace", "drive", "total", "space", "block", "valid", "onion", "start", "exact", "vague", "child", "steak",
    "crowd", "build", "lemon", "virus", "house", "sharp", "storm", "court", "obese", "flush", "dozen", "upset", "grave"
}
local correctColour = sm.color.new(0.47,0.69,0.34,1)
local semicorrectColour = sm.color.new(0.99,0.79,0.34,1)
local incorrectColour = sm.color.new(0.19,0.21,0.23,1)

local function findLetterInString( str, letter )
    local present = false
    local indexes = {}

    for i = 1, #str do
        if str:sub(i,i) == letter then
            present = true
            indexes[#indexes+1] = i
        end
    end

    return present, indexes
end

function Wordle:client_onCreate()
    self.cl = {
        gui = sm.gui.createGuiFromLayout( "$CONTENT_DATA/Gui/wordle.layout" ),
        currentWord = "",
        wordProgress = "",
        currentRow = 1,
        canProgress = true
    }

    self.cl.gui:setOnCloseCallback("cl_reset")
    self.cl.gui:setTextAcceptedCallback( "input", "cl_input")

    for i = 1, 5 do
        local widget = "letter"..tostring(self.cl.currentRow).."_"..tostring(i)
        self.cl.gui:setColor(widget.."_col", incorrectColour)
        self.cl.gui:setText(widget, " ")
    end

    self.cl.resetTimer = Timer()
    self.cl.resetTimer:start( 5 * 40 )
end

function Wordle:cl_start()
    for i = 1, 6 do
        self.cl.gui:setVisible("row"..tostring(i), i == 1)
    end

    self.cl.gui:open()
    self.cl.currentWord = words[math.random(#words)]
    sm.gui.chatMessage("New word generated! Good luck guessing it!")
    sm.audio.play("Blueprint - Open")
end

function Wordle:cl_reset()
    self.cl.currentWord = ""
    self.cl.wordProgress = ""
    self.cl.currentRow = 1
    self.cl.canProgress = true
    self.cl.resetTimer:reset()

    self.cl.gui:setText( "input", "" )

    for row = 1, 6 do
        for columm = 1, 5 do
            local widget = "letter"..tostring(row).."_"..tostring(columm)
            self.cl.gui:setColor(widget.."_col", incorrectColour)
            self.cl.gui:setText(widget, " ")
        end
    end
end

function Wordle:cl_input( editBox, text )
    if not self.cl.canProgress then return end

    if type(text) ~= "string" or text:len() ~= 5 then
        sm.gui.chatMessage("#ff0000Words must be 5 characters long!")
        sm.audio.play("RaftShark")
        return
    end

    self.cl.gui:setText( "input", "" )

    self.cl.wordProgress = text
    local correctLetters = 0
    local indexesByLetter = {}
    for i = 1, 5 do
        local widget = "letter"..tostring(self.cl.currentRow).."_"..tostring(i)
        local letter = self.cl.wordProgress:sub(i,i)
        local present, indexes = findLetterInString(self.cl.currentWord, letter)
        if indexesByLetter[letter] == nil then
            indexesByLetter[letter] = #indexes
        end

        local isCorrectLetter = letter == self.cl.currentWord:sub(i,i)
        if present and isCorrectLetter then
            correctLetters = correctLetters + 1
        end

        local colour = (present and indexesByLetter[letter] > 0 ) and (isCorrectLetter and correctColour or semicorrectColour) or incorrectColour
        indexesByLetter[letter] = indexesByLetter[letter] - 1

        self.cl.gui:setColor(widget.."_col", colour)
        self.cl.gui:setText(widget, letter:upper())
    end


    if correctLetters == 5 then
        sm.gui.chatMessage( string.format("%sYou guessed the word right, it was '#ffffff%s'%s!", "#00ff00", self.cl.currentWord, "#00ff00"))
        sm.effect.playEffect("Part - Upgrade", self.shape.worldPosition, sm.vec3.zero(), sm.vec3.getRotation(sm.vec3.new(0,1,0), sm.vec3.new(0,0,1)))
        --self.cl.gui:close()
        --self:cl_reset()
        self.cl.canProgress = false

        return
    elseif self.cl.currentRow == 6 then
        sm.gui.chatMessage( string.format("%sYou failed! The word was '#ffffff%s%s'!", "#ff0000", self.cl.currentWord, "#ff0000"))
        sm.audio.play("RaftShark")
        --self.cl.gui:close()
        --self:cl_reset()
        self.cl.canProgress = false

        return
    end


    self.cl.currentRow = self.cl.currentRow + 1
    for i = 1, 6 do
        self.cl.gui:setVisible("row"..tostring(i), i <= self.cl.currentRow)
    end

    for j = 1, 5 do
        local widget = "letter"..tostring(self.cl.currentRow).."_"..tostring(j)
        self.cl.gui:setColor(widget.."_col", incorrectColour)
        self.cl.gui:setText(widget, "")
    end
end

function Wordle:client_onInteract( char, state )
    if state then self:cl_start() end
end

function Wordle:client_onFixedUpdate()
    if not self.cl.canProgress then
        self.cl.resetTimer:tick()
        if self.cl.resetTimer:done() then
            self:cl_reset()
            self:cl_start()
        end
    end
end