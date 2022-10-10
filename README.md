# confiture.nvim

A simple way to save and launch your project specific commands.


## Main features/motivations

- Use the same simple vim commands (for example `:Confiture build_and_run`), or better, mappings, to launch build commands in all your projects.
- Have your project specific commands stored with your project files and not in your `init.vim`/`init.lua`.
- Have a `build_and_run` function to build with a call to `:make` and run a command if the build succeeds. 
- Support for asynchronous builds and commands using [tpope/vim-dispatch](https://github.com/tpope/vim-dispatch) and the integrated nvim terminal.
- Keeping it simple: leverage standard neovim features, use as less vimrc configuration as possible, and provide a configuration file format that is easy to tweak.


## Installation

Install with your package manager of choice, for example with [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'romainchapou/confiture.nvim'
```


## Usage

First, create a `project.conf` file in your project root directory. This is where you will define your project commands (which simply are the shell commands you would use in a terminal). The file follows a simple syntax:

```conf
# my project.conf file

# declaring variables
variable: "confiture <3"

# declaring commands
@build:      "make -j16"
@run:        "./run_test"
@my_command: "echo ${variable}"
```

Then start neovim in this same folder and use `:Confiture` to launch your commands.


### `project.conf` content

_Note_: if you want to have another name for your Confiture configuration files, simply set `g:confiture_file_name` in your `init.vim`/`init.lua` to what you prefer.

- Vimscript example: `let g:confiture_file_name = "my_config.whatever"`
- Lua example: `vim.g.confiture_file_name = "my_config.whatever"`


#### Commands

Commands are declared with a `@` and assigned a value with `:`. Any name is valid, but `@build` and `@run` have a special meaning. The command "`cmd`" can then be executed from Neovim with a call to `:Confiture cmd` (with nice completion).

- `@build`: set the command to `makeprg` and execute it with `:make` (to get errors/warnings in the quickfix list). If [tpope/vim-dispatch](https://github.com/tpope/vim-dispatch) is installed, use `:Make` instead to build asynchronously.
- `@run`: launch the command in a new terminal window (if not specified otherwise, see the `RUN_IN_TERM` variable)
- any other command: will be be launched with a call to `:!`

If this default behaviour doesn't suit you, you can always launch any command with [tpope/vim-dispatch](https://github.com/tpope/vim-dispatch) or the integrated nvim terminal using `:ConfitureDispatch` and `:ConfitureTerm`.

Variables can be used in your command definition using the `${var}` syntax, as well as other commands using the `@{cmd}` syntax (see the example section).


#### Variables

Variables can be assigned a value with `:` and then used in other variables or in commands using the `${var}` syntax. Variables names can be anything you want, although some have a special meaning:

- `RUN_IN_TERM` (boolean): if true, the `@run` command will be launched in a nvim terminal window. If false, a simple call to `:!` will be made. **Defaults to true**.
- `DISPATCH_BUILD` (boolean): if true, use [tpope/vim-dispatch](https://github.com/tpope/vim-dispatch) for asynchronous builds if available. **Defaults to true**.
- `COMPILER` (string): the value should be a valid option of `:compiler`. Used to set neovim's `errorformat`. NOTE: the `makeprg` of the build command will not be affected by this. **Defaults to ""** (use the default errorformat, adapted for C/C++)


#### `:Confiture build_and_run`

`:Confiture build_and_run` is an additional command implicitly defined by `@build` and `@run`.

- If there is a `@build` command defined, launch the `build` command. Then, if it succeeded, launch the `run` command.
- If there is no `@build` command defined, simply launch the `run` command.

This will not use [tpope/vim-dispatch](https://github.com/tpope/vim-dispatch).


### Examples

#### A super simple example for a script project

```conf
# my simple project.conf

# will be launched by either ':Confiture run' or ':Confiture build_and_run'
@run: "./main.py"
```


#### A simple example using `make`

```conf
# my project.conf for a simple cpp project using make
RUN_IN_TERM: false # run command will be executed with a simple call to ':!'

@build: "make -j16"
@run:   "./my_exec"
@clean: "make clean"
```


#### A more complex example for a `cmake` project

```conf
# my project.conf for a cmake project
build_type: "Release"
build_folder: "build-${build_type}"

@configure:     "mkdir -p ${build_folder} && cmake -B ${build_folder} -DCMAKE_BUILD_TYPE ${build_type}"
@build:         "make -j16 -C ${build_folder}"
@run:           "${build_folder}/test/my_test"
@clean:         "make -C ${build_folder} clean"
@clean_rebuild: "@{clean} && @{configure} && @{build}" # chaining commands!
```


### Advanced notes

- When using the `${var}` syntax inside a command definition, `var` will be expanded with quotes. Inside a variable definition, `${var}` will be expanded **WITHOUT** quotes. For example, with the following configuration, `:Confiture my_command` is equivalent to `:!echo "ls "$HOME/my path/with spaces/my_dir/"`.

```conf
# my project.conf
root: "$HOME/my path/with spaces/"
dir: "${root}/my_dir/"
@my_command: "ls ${dir}"
```

- When using the `@{cmd}` syntax, `cmd` will be expanded **WITHOUT** quotes, so you can chain commands. For example, with the following configuration, `:Confiture my_command` is equivalent to `:!echo hi && echo hello`.

```conf
# my project.conf
@cmd1: "echo hi"
@cmd2: "echo hello"
@my_command: "@{cmd1} && @{cmd2}"
```

- The commands defined in your `project.conf` file will be directly executed by neovim commands. This has a few impacts:
    - `%` to specify the current file, and other vim shortcuts, will work.
    - The shell used will be depend of your vim configuration (probably the one used to start vim). Note that if your shell happens to be something other than `bash` or `zsh`, the detection of a successful build used in `@build_and_run` may not work.

- As commands and string variable values are given by `"` delimited strings, you have to escape the quotes (`\"`) if you want literal `"` characters in your variables/commands. Every other character will be interpreted as is, including any `\` not followed by a `"`. 

- For some reason, launching an nvim terminal with, as argument, a command to be disowned (something like `:term my_shell_cmd & disown`) doesn't seem to work. This means that having command such as `@my_cmd: "./my_exec & disown"` and using `:ConfitureTerm my_cmd` will not keep `my_exec` open.


### Some recommended mappings

```vim
" Save all buffers (ignore unnamed ones) and run a command
nnoremap <leader>c :silent wa<cr>:ConfitureDispatch configure<cr>
nnoremap <leader>b :silent wa<cr>:Confiture build<cr>
" double <cr> to skip the confirmation prompt
nnoremap <leader><cr> :silent wa<cr>:Confiture build_and_run<cr><cr>
```
