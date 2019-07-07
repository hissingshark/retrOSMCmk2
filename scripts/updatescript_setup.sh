
# wrapper function to allow patching of RetroPie-Setup post update
function updatescript_setup() {
    # call the original function
    updatescript_setup_original
    # patch upon exit
    calling patch function
}
