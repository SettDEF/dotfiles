-- nui-components highlight overrides — semantic Material palette only.
local P = require("core.hls.palette")

return {
    hl = {
        NuiComponentsTreeNodeFocused        = { bg = P.surface_container },
        NuiComponentsSelectNodeFocused      = { bg = P.surface_container_low },
        NuiComponentsButtonActive           = { fg = P.on_primary, bg = P.primary_container },
        NuiComponentsTreeSpectreReplaceSuccess = { fg = P.on_surface_variant },
        NuiComponentsBorderLabel            = { fg = P.on_surface_variant, bg = P.surface_container },

        NuiSelectItem         = { bg = P.primary_container },
        NuiSelectItemActive   = { bg = P.background },
        NuiSelectSeparator    = { fg = P.outline },
        NuiSelectItemSelected = { fg = P.tertiary },
        NuiFooterConfirmButton = { fg = P.primary },
        NuiFooterCancelButton  = { fg = P.secondary },
    },
}
