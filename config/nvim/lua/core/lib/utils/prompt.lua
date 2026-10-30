local openai = require("model.providers.openai")
local model = require("model")
local util = require("model.util")
-- local segment = require("model.segment")

return {
    code = {
        provider = openai,
        builder = function(input)
            return {
                messages = {
                    {
                        role = "system",
                        content = "You are a 10x super elite programmer. Continue only with code. Do not write tests, examples, or output of code unless explicitly asked for.",
                    },
                    {
                        role = "user",
                        content = input,
                    },
                },
            }
        end,
    },
    codePlus = {
        provider = openai,
        builder = function(input)
            local messages = {
                {
                    role = "system",
                    content = "You are a 10x super elite programmer. Continue only with code. Do not write tests, examples, or output of code unless explicitly asked for.",
                },
                {
                    role = "user",
                    content = input,
                },
            }

            return function(build)
                vim.ui.input(
                    { prompt = "Additional instruction for prompt: " },
                    function(user_input)
                        if user_input == nil then
                            return
                        end

                        if #user_input > 0 then
                            table.insert(messages, {
                                role = "user",
                                content = user_input,
                            })
                        end

                        build({
                            messages = messages,
                        })
                    end
                )
            end
        end,
    },
    ["to spanish"] = {
        provider = openai,
        hl_group = "SpecialComment",
        builder = function(input)
            return {
                messages = {
                    {
                        role = "system",
                        content = "Translate to Spanish",
                    },
                    {
                        role = "user",
                        content = input,
                    },
                },
            }
        end,
        mode = model.mode.INSERT_OR_REPLACE,
    },
    ["to English"] = {
        provider = openai,
        hl_group = "SpecialComment",
        builder = function(input)
            return {
                messages = {
                    {
                        role = "system",
                        content = "Translate to English",
                    },
                    {
                        role = "user",
                        content = input,
                    },
                },
            }
        end,
        mode = model.mode.INSERT_OR_REPLACE,
    },
    ["to German"] = {
        provider = openai,
        hl_group = "SpecialComment",
        builder = function(input)
            return {
                messages = {
                    {
                        role = "system",
                        content = "Translate to German",
                    },
                    {
                        role = "user",
                        content = input,
                    },
                },
            }
        end,
        mode = model.mode.INSERT_OR_REPLACE,
    },
    ["to javascript"] = {
        provider = openai,
        builder = function(input, ctx)
            return {
                messages = {
                    {
                        role = "system",
                        content = "Convert the code to javascript",
                    },
                    {
                        role = "user",
                        content = input,
                    },
                },
            }
        end,
    },
    ["to rap"] = {
        provider = openai,
        hl_group = "Title",
        builder = function(input)
            return {
                messages = {
                    {
                        role = "system",
                        content = "Explain the code in 90's era rap lyrics",
                    },
                    {
                        role = "user",
                        content = input,
                    },
                },
            }
        end,
    },
    askPlus = {
        provider = openai,
        params = {
            temperature = 0.3,
            max_tokens = 1500,
        },
        builder = function(input)
            local messages = {
                {
                    role = "user",
                    content = input,
                },
            }

            return function(build)
                vim.ui.input(
                    { prompt = "Additional instruction for prompt: " },
                    function(user_input)
                        if user_input == nil then
                            return
                        end

                        if #user_input > 0 then
                            table.insert(messages, {
                                role = "user",
                                content = user_input,
                            })
                        end

                        build({
                            messages = messages,
                        })
                    end
                )
            end
        end,
    },
}
