wg-captive-browser
==

wg-captive-browser helps you connect to captive portals (guest wifi splash pages) without needing to disable your wireguard interface. It uses linux network namespaces to create a temporary namespace that does not get routed through the wireguard interface.

wg-captive-browser is intended to be used with wg-quick and captive-browser[1]. It assumes you are routing all your traffic through the wg interface by using `ip rules` (which is what wg-quick does on linux).

[1]: https://github.com/FiloSottile/captive-browser
