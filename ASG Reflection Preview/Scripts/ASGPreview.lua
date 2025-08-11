---@class ASGPreview : ShapeClass
ASGPreview = class()

function ASGPreview:client_onCreate()
    self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/asgpreview.layout")
    self.gui:setImage("map", "$CONTENT_DATA/Objects/Textures/obj_tutorial_referenceblockasg_asg.tga")
    self.gui:createHorizontalSlider("uv_hor", 1025, 0, "cl_uvHor", false)
    self.gui:createHorizontalSlider("uv_ver", 1025, 0, "cl_uvVer", false)
    self.gui:createHorizontalSlider("glow", 101, 0, "cl_glow", false)

    self.hor = 0
    self.ver = 0
    self.glow = 0
    self:cl_updateUv()
end

function ASGPreview:cl_uvHor(value)
    self.hor = value
    self:cl_updateUv()
end

function ASGPreview:cl_uvVer(value)
    self.ver = value
    self:cl_updateUv()
end

function ASGPreview:cl_glow(value)
    self.glow = value / 100
    self:cl_updateUv()
end

function ASGPreview:cl_updateUv()
    self.interactable:setUvFrameIndex(self.ver * 1024 + self.hor)
    self.interactable:setGlowMultiplier(self.glow)

    print(self.hor)
    self.gui:setText("uv_hor_percent", ("%.1f"):format(self.hor/1024*100))
    self.gui:setText("uv_ver_percent", ("%.1f"):format(self.ver/1024*100))
    self.gui:setText("uv_glow_percent", tostring(self.glow * 100))
end

function ASGPreview:client_onInteract(char, state)
    if not state then return end

    self.gui:open()
end