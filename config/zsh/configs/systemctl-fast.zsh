# systemctl completion: zsh's own asks systemd about every unit on each Tab (seconds); these list once a minute
typeset -ga _sysfast_units; typeset -gi _sysfast_at=0
_sysfast_list() {
    (( EPOCHSECONDS - _sysfast_at < 60 )) && [[ $_sysfast_mgr == $_sys_service_mgr ]] && return
    _sysfast_units=( ${${${(f)"$(systemctl $_sys_service_mgr list-units --all --no-legend --no-pager --plain 2>/dev/null; systemctl $_sys_service_mgr list-unit-files --no-legend --no-pager 2>/dev/null)"}%%[[:space:]]*}:#*@.*} )
    _sysfast_units=( ${(u)_sysfast_units} ); _sysfast_at=$EPOCHSECONDS; typeset -g _sysfast_mgr=$_sys_service_mgr
}
zmodload -F zsh/datetime p:EPOCHSECONDS
_systemctl_restartable_units() { _sysfast_list; _sys_restartable_units=( $_sysfast_units ) }
_systemctl_startable_units()   { _sysfast_list; _sys_startable_units=( $_sysfast_units ) }
