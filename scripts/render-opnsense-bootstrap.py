#!/usr/bin/env python3
"""Render a network-specific OPNsense bootstrap config from a trusted backup."""

import argparse
import base64
from pathlib import Path
import xml.etree.ElementTree as ET


INTERFACES = {
    "wan": ("WAN1", "vtnet0", "dhcp", None),
    "opt1": ("WAN2", "vtnet1", "dhcp", None),
    "opt2": ("MGMT", "vtnet2", "10.0.10.1", "24"),
    "lan": ("DEVICES", "vtnet3", "10.0.20.1", "24"),
    "opt3": ("IOT", "vtnet4", "10.0.30.1", "24"),
    "opt4": ("HOMELAB", "vtnet5", "10.0.40.1", "24"),
}


def set_text(parent: ET.Element, name: str, value: str | None = None) -> None:
    element = parent.find(name)
    if element is None:
        element = ET.SubElement(parent, name)
    element.text = value


def configure_interface(
    interfaces: ET.Element,
    name: str,
    description: str,
    device: str,
    address: str,
    subnet: str | None,
) -> None:
    interface = interfaces.find(name)
    if interface is None:
        interface = ET.SubElement(interfaces, name)

    for field in ("if", "descr", "ipaddr", "subnet", "gateway", "enable"):
        existing = interface.find(field)
        if existing is not None:
            interface.remove(existing)

    set_text(interface, "enable")
    set_text(interface, "if", device)
    set_text(interface, "descr", description)
    set_text(interface, "ipaddr", address)
    if subnet:
        set_text(interface, "subnet", subnet)


def add_bootstrap_rule(
    filter_config: ET.Element,
    description: str,
    interface: str,
    source_address: str,
    destination_network: str,
) -> None:
    if any(rule.findtext("descr") == description for rule in filter_config.findall("rule")):
        return

    rule = ET.SubElement(filter_config, "rule")
    set_text(rule, "type", "pass")
    set_text(rule, "interface", interface)
    set_text(rule, "ipprotocol", "inet")
    set_text(rule, "protocol", "tcp")
    source = ET.SubElement(rule, "source")
    set_text(source, "address", source_address)
    destination = ET.SubElement(rule, "destination")
    set_text(destination, "network", destination_network)
    set_text(rule, "descr", description)


def configure_root_ssh_key(root: ET.Element, public_key_path: Path) -> None:
    public_key = public_key_path.expanduser().read_text(encoding="utf-8").strip()
    if not public_key:
        raise SystemExit(f"SSH public key is empty: {public_key_path}")

    root_user = next(
        (user for user in root.findall("./system/user") if user.findtext("name") == "root"),
        None,
    )
    if root_user is None:
        raise SystemExit("factory configuration does not contain the root user")
    encoded_key = base64.b64encode(public_key.encode("utf-8")).decode("ascii")
    set_text(root_user, "authorizedkeys", encoded_key)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path, help="Base OPNsense configuration")
    parser.add_argument("output", type=Path, help="Rendered bootstrap config")
    parser.add_argument(
        "--ssh-public-key",
        type=Path,
        default=Path("~/.ssh/id_ed25519.pub"),
        help="Public key authorized for the temporary root SSH login",
    )
    args = parser.parse_args()

    tree = ET.parse(args.source)
    root = tree.getroot()
    if root.tag != "opnsense":
        raise SystemExit("source is not an OPNsense configuration backup")

    interfaces = root.find("interfaces")
    if interfaces is None:
        interfaces = ET.SubElement(root, "interfaces")
    for name, values in INTERFACES.items():
        configure_interface(interfaces, name, *values)

    system = root.find("system")
    if system is None:
        system = ET.SubElement(root, "system")
    set_text(system, "disablechecksumoffloading", "1")
    set_text(system, "disablesegmentationoffloading", "1")
    set_text(system, "disablelargereceiveoffloading", "1")
    configure_root_ssh_key(root, args.ssh_public_key)
    filter_config = root.find("filter")
    if filter_config is None:
        filter_config = ET.SubElement(root, "filter")
    for existing_rule in filter_config.findall("rule"):
        filter_config.remove(existing_rule)
    add_bootstrap_rule(
        filter_config,
        "Allow Apollo bootstrap access",
        "opt2",
        "10.0.10.2",
        "opt2ip",
    )
    add_bootstrap_rule(
        filter_config,
        "Allow devices bootstrap access",
        "lan",
        "10.0.20.0/24",
        "lanip",
    )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(tree, space="  ")
    tree.write(args.output, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    main()
