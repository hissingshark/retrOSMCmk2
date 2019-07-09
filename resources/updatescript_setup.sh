
# wrapper function to allow patching of RetroPie-Setup post update
# keyword to indicate patch has been applied -> retrOSMC_Patched
function updatescript_setup() {
    # updates only revert patches in files that have been changed by the update, but in those cases patches prevent the update...
    # remove our patches
    git -C $scriptdir reset --hard HEAD

    # call the original function
    updatescript_setup_original

    # patch before exit
    $scriptdir/../../setup.sh PATCH
}
