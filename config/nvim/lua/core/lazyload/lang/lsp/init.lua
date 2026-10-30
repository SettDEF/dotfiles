local LU = require("lspconfig.util")
local C = require("core.lazyload.lang.lsp.config")

-- HTML Language Server
vim.lsp.config("html", {
    filetypes = { "html" },
    root_dir = LU.root_pattern("*.html", ".git"),
    capabilities = C.capabilities,
    on_attach = C.on_attach,
})

-- CSS / SCSS / Sass Language Server
vim.lsp.config(
    "cssls",
    vim.tbl_extend("force", C.default or {}, {
        cmd = { "vscode-css-language-server", "--stdio" },
        filetypes = { "css", "scss", "sass", "less" },
        root_markers = {
            "package.json",
            "tsconfig.json",
            "jsconfig.json",
            ".stylelintrc",
            ".stylelintrc.json",
            ".stylelintrc.js",
            "stylelint.config.js",
            ".git",
        },
        settings = {
            css = { validate = true, lint = { unknownAtRules = "ignore" } },
            scss = { validate = true, lint = { unknownAtRules = "ignore" } },
            sass = { validate = true },
            less = { validate = true },
        },
    })
)

-- Optional: somesass_ls — modern Sass/SCSS server with variable / mixin /
-- placeholder navigation that cssls can't do. Enabled only when the binary
-- is installed (npm i -g some-sass-language-server).
if vim.fn.executable("some-sass-language-server") == 1 then
    vim.lsp.config(
        "somesass_ls",
        vim.tbl_extend("force", C.default or {}, {
            cmd = { "some-sass-language-server", "--stdio" },
            filetypes = { "scss", "sass" },
            root_markers = { "package.json", ".git" },
        })
    )
end

-- TypeScript / JavaScript
vim.lsp.config(
    "ts_ls",
    vim.tbl_extend("force", C.default or {}, {
        cmd = { "typescript-language-server", "--stdio" },
        filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
        root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
        settings = {
            typescript = {
                inlayHints = {
                    includeInlayParameterNameHints = "all",
                    includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                    includeInlayFunctionParameterTypeHints = true,
                    includeInlayVariableTypeHints = true,
                    includeInlayPropertyDeclarationTypeHints = true,
                    includeInlayFunctionLikeReturnTypeHints = true,
                    includeInlayEnumMemberValueHints = true,
                },
            },
            javascript = {
                inlayHints = {
                    includeInlayParameterNameHints = "all",
                    includeInlayEnumMemberValueHints = true,
                },
            },
        },
    })
)

-- ESLint
vim.lsp.config("eslint", {
    filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    root_markers = {
        ".eslintrc.js",
        ".eslintrc.cjs",
        ".eslintrc.json",
        ".eslintrc",
        "eslint.config.js",
        "eslint.config.mjs",
        "eslint.config.cjs",
        "package.json",
        ".git",
    },
    settings = {
        format = { enable = true },
        workingDirectory = { mode = "auto" },
    },
    capabilities = C.capabilities,
    on_attach = function(client, bufnr)
        C.on_attach(client, bufnr)
        vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = bufnr,
            callback = function()
                vim.lsp.buf.format({ async = false })
            end,
        })
    end,
})

-- JSON
vim.lsp.config("jsonls", {
    filetypes = { "json", "jsonc" },
    root_dir = LU.root_pattern("package.json", "*.json", ".git"),
    settings = {
        json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
        },
    },
    capabilities = C.capabilities,
    on_attach = C.on_attach,
})

-- Python
vim.lsp.config(
    "pyright",
    vim.tbl_extend("force", C.default or {}, {
        filetypes = { "python" },
    })
)

-- Docker
vim.lsp.config("dockerls", {
    filetypes = { "dockerfile" },
    root_dir = LU.root_pattern("[dD]ockerfile*", ".dockerignore", ".git"),
    capabilities = C.capabilities,
    on_attach = C.on_attach,
})

vim.lsp.config("docker_compose_language_service", {
    filetypes = { "yaml", "yml" },
    root_dir = LU.root_pattern("docker-compose.ya?ml", "compose.ya?ml", ".git"),
    capabilities = C.capabilities,
    on_attach = C.on_attach,
})

-- YAML
vim.lsp.config(
    "yamlls",
    vim.tbl_extend("force", C.default or {}, {
        filetypes = { "yaml", "yml" },
    })
)

-- Terraform
vim.lsp.config(
    "terraformls",
    vim.tbl_extend("force", C.default or {}, {
        filetypes = { "terraform", "tf", "terraform-vars" },
    })
)

-- Bash / Zsh. bash-language-server has partial zsh support: hover for
-- POSIX-shared builtins works, but shellcheck bails on zsh-only syntax.
-- We attach it to zsh anyway for hover + goto, and silence shellcheck on
-- zsh buffers by pointing it at /dev/null so the server keeps running
-- without spamming diagnostics.
vim.lsp.config("bashls", {
    filetypes = { "sh", "bash", "zsh" },
    root_dir = LU.root_pattern(".git", ".sh", ".zsh", ".zshrc", "configure.ac", "Makefile"),
    settings = {
        bashIde = {
            globPattern = "@(.sh|.bash|.zsh|.command)",
            shfmt = { path = vim.fn.exepath("shfmt") },
            shellcheck = { path = vim.fn.exepath("shellcheck") },
        },
    },
    capabilities = C.capabilities,
    on_attach = function(client, bufnr)
        C.on_attach(client, bufnr)
        if vim.bo[bufnr].filetype == "zsh" then
            vim.diagnostic.enable(false, { bufnr = bufnr })
        end
    end,
})

vim.lsp.config("qmlls", {
    filetypes = { "qml" },
    capabilities = C.capabilities,
    on_attach = function(client, bufnr)
        if C.on_attach then
            C.on_attach(client, bufnr)
        end
        -- qmlls' semantic tokens are sparse and paint the `import` keyword and
        -- module path nearly invisible, overriding QML's bright vim-syntax
        -- highlighting (qmlReserved → Keyword → primary). Drop them so syntax
        -- wins and `import` stays legible.
        client.server_capabilities.semanticTokensProvider = nil
    end,
})

-- Lua
vim.lsp.config(
    "lua_ls",
    vim.tbl_extend("force", C.default or {}, {
        filetypes = { "lua" },
        settings = {
            Lua = {
                runtime = { version = "LuaJIT" },
                workspace = {
                    checkThirdParty = false,
                    library = {
                        vim.fn.stdpath("config"),
                        vim.api.nvim_get_runtime_file("", true),
                    },
                },
                diagnostics = { globals = { "vim" } },
                telemetry = { enable = false },
            },
        },
    })
)

-- Elixir
vim.lsp.config("elixirls", {
    filetypes = { "elixir", "eelixir", "heex" },
    root_dir = function(fname)
        return LU.root_pattern("mix.exs", ".git")(fname)
    end,
    capabilities = C.capabilities,
    on_attach = C.on_attach,
})

-- PHP - Intelephense
vim.lsp.config(
    "intelephense",
    vim.tbl_extend("force", C.default or {}, {
        filetypes = { "php", "phtml" },
        root_dir = LU.root_pattern("composer.json", ".git", ".php"),
        settings = {
            intelephense = {
                files = {
                    maxSize = 5000000, -- 5MB
                },
                diagnostics = {
                    enable = true,
                    undefinedTypes = true,
                    undefinedFunctions = true,
                    undefinedConstants = true,
                    undefinedClassConstants = true,
                    undefinedMethods = true,
                    undefinedProperties = true,
                    undefinedVariables = true,
                },
                format = {
                    enable = true,
                },
                stubs = {
                    "apache",
                    "bcmath",
                    "bz2",
                    "calendar",
                    "com_dotnet",
                    "Core",
                    "ctype",
                    "curl",
                    "date",
                    "dba",
                    "dom",
                    "enchant",
                    "exif",
                    "FFI",
                    "fileinfo",
                    "filter",
                    "fpm",
                    "ftp",
                    "gd",
                    "gettext",
                    "gmp",
                    "hash",
                    "iconv",
                    "imap",
                    "intl",
                    "json",
                    "ldap",
                    "libxml",
                    "mbstring",
                    "meta",
                    "mysqli",
                    "oci8",
                    "odbc",
                    "openssl",
                    "pcntl",
                    "pcre",
                    "PDO",
                    "pdo_mysql",
                    "pdo_pgsql",
                    "pdo_sqlite",
                    "pgsql",
                    "Phar",
                    "posix",
                    "pspell",
                    "readline",
                    "Reflection",
                    "session",
                    "shmop",
                    "SimpleXML",
                    "snmp",
                    "soap",
                    "sockets",
                    "sodium",
                    "SPL",
                    "sqlite3",
                    "standard",
                    "superglobals",
                    "sysvmsg",
                    "sysvsem",
                    "sysvshm",
                    "tidy",
                    "tokenizer",
                    "xml",
                    "xmlreader",
                    "xmlrpc",
                    "xmlwriter",
                    "xsl",
                    "Zend OPcache",
                    "zip",
                    "zlib",
                    -- WordPress / Laravel / Symfony
                    "wordpress",
                    "woocommerce",
                    "laravel",
                    "symfony",
                },
                environment = {
                    includePaths = {},
                    phpVersion = "8.2",
                },
                trace = {
                    server = "off",
                },
            },
        },
        init_options = {
            licenceKey = os.getenv("INTELEPHENSE_LICENCE"),
            clearCache = false,
        },
        on_attach = function(client, bufnr)
            if C.on_attach then
                C.on_attach(client, bufnr)
            end

            local bufopts = { noremap = true, silent = true, buffer = bufnr }
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
            vim.keymap.set("n", "gr", vim.lsp.buf.references, bufopts)
            vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
            vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, bufopts)
            vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, bufopts)
            vim.keymap.set("n", "<leader>f", function()
                vim.lsp.buf.format({ async = true })
            end, bufopts)
            vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
            vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help, bufopts)
            vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, bufopts)
            vim.keymap.set("n", "]d", vim.diagnostic.goto_next, bufopts)
            vim.keymap.set("n", "<leader>ih", function()
                vim.b.inlay_hints_enabled = not vim.b.inlay_hints_enabled
                vim.lsp.inlay_hint.enable(vim.b.inlay_hints_enabled, { bufnr = bufnr })
            end, bufopts)

            vim.b.inlay_hints_enabled = true
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
        end,
    })
)

-- C/C++ (merged)
vim.lsp.config(
    "clangd",
    vim.tbl_extend("force", C.default or {}, {
        filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
        root_dir = LU.root_pattern(
            ".clangd",
            ".clang-tidy",
            ".clang-format",
            "compile_commands.json",
            "compile_flags.txt",
            "configure.ac",
            ".git"
        ),
        cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--completion-style=detailed",
            "--header-insertion=iwyu",
            "--function-arg-placeholders",
            "--fallback-style=llvm",
            "--all-scopes-completion",
            "--inlay-hints",
        },
        init_options = {
            fallbackFlags = { "-std=c++23" },
        },
        capabilities = vim.tbl_deep_extend("force", C.capabilities or {}, {
            offsetEncoding = { "utf-16" },
        }),
        on_attach = function(client, bufnr)
            if C.on_attach then
                C.on_attach(client, bufnr)
            end

            if client.server_capabilities.inlayHintProvider then
                vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
            end

            local bufopts = { noremap = true, silent = true, buffer = bufnr }
            vim.keymap.set("n", "<leader>sh", ":ClangdSwitchSourceHeader<CR>", bufopts)
        end,
    })
)

vim.lsp.config("slint_lsp", {
    on_attach = function(client, bufnr)
        local opts = { noremap = true, silent = true, buffer = bufnr }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)

        vim.opt_local.textwidth = 0
        vim.opt_local.wrapmargin = 0
        vim.opt_local.formatoptions:remove("t")
        vim.opt_local.formatoptions:remove("c")

        vim.opt_local.wrap = true
        vim.opt_local.linebreak = true
    end,

    cmd = { "slint-lsp" },
    filetypes = { "slint" },
})

vim.lsp.enable("slint_lsp")

-- Enable all servers (place this at the end of the file)
vim.lsp.enable({
    "html",
    "cssls",
    "ts_ls",
    "eslint",
    "jsonls",
    "pyright",
    "dockerls",
    "docker_compose_language_service",
    "yamlls",
    "terraformls",
    "clangd",
    "bashls",
    "lua_ls",
    "elixirls",
    "intelephense",
})

if vim.fn.executable("some-sass-language-server") == 1 then
    vim.lsp.enable("somesass_ls")
end
