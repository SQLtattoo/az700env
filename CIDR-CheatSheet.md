# CIDR & Subnetting Cheat Sheet

## 1. What is CIDR?

CIDR = **Classless Inter-Domain Routing**

Example:

```text id="c1"
10.0.0.0/24
```

The:

```text id="c2"
/24
```

means:

> First 24 bits belong to the NETWORK.

IPv4 addresses always have:

```text id="c3"
32 bits total
```

---

# 2. Quick Rule

## Bigger CIDR = Smaller Network

| CIDR | Approx Hosts |
| ---- | ------------ |
| /16  | Huge         |
| /24  | Medium       |
| /30  | Tiny         |

---

# 3. Host Formula

Traditional networking:

```text id="c4"
2^(32 - CIDR) - 2
```

Azure practical usable IPs:

```text id="c5"
2^(32 - CIDR) - 5
```

Because Microsoft [Azure](https://azure.microsoft.com?utm_source=chatgpt.com) reserves 5 IP addresses per subnet.

---

# 4. Common CIDR Sizes

| CIDR | Subnet Mask     | Total IPs | Azure Usable |
| ---- | --------------- | --------- | ------------ |
| /30  | 255.255.255.252 | 4         | N/A          |
| /29  | 255.255.255.248 | 8         | 3            |
| /28  | 255.255.255.240 | 16        | 11           |
| /27  | 255.255.255.224 | 32        | 27           |
| /26  | 255.255.255.192 | 64        | 59           |
| /25  | 255.255.255.128 | 128       | 123          |
| /24  | 255.255.255.0   | 256       | 251          |
| /23  | 255.255.254.0   | 512       | 507          |
| /22  | 255.255.252.0   | 1024      | 1019         |
| /21  | 255.255.248.0   | 2048      | 2043         |

---

# 5. Binary Values Table

| Bit | Value |
| --- | ----- |
| 1   | 128   |
| 2   | 64    |
| 3   | 32    |
| 4   | 16    |
| 5   | 8     |
| 6   | 4     |
| 7   | 2     |
| 8   | 1     |

---

# 6. Binary → Decimal Pattern

| Binary   | Decimal |
| -------- | ------- |
| 10000000 | 128     |
| 11000000 | 192     |
| 11100000 | 224     |
| 11110000 | 240     |
| 11111000 | 248     |
| 11111100 | 252     |
| 11111110 | 254     |
| 11111111 | 255     |

Memorize this table.
It solves most subnetting problems fast.

---

# 7. Example — `/24`

CIDR:

```text id="c6"
/24
```

Binary subnet mask:

```text id="c7"
11111111.11111111.11111111.00000000
```

Decimal subnet mask:

```text id="c8"
255.255.255.0
```

Hosts:

```text id="c9"
256 total
251 usable in Azure
```

Range:

```text id="c10"
10.0.0.0 → 10.0.0.255
```

Usable:

```text id="c11"
10.0.0.4 → 10.0.0.254
```

---

# 8. Example — `/22`

CIDR:

```text id="c12"
/22
```

Binary subnet mask:

```text id="c13"
11111111.11111111.11111100.00000000
```

Decimal subnet mask:

```text id="c14"
255.255.252.0
```

Hosts:

```text id="c15"
1024 total
1019 usable in Azure
```

Range:

```text id="c16"
10.0.0.0 → 10.0.3.255
```

Usable:

```text id="c17"
10.0.0.4 → 10.0.3.254
```

---

# 9. How to Calculate Subnet Mask

Example:

```text id="c18"
/22
```

Means:

```text id="c19"
22 ON bits
```

Binary:

```text id="c20"
11111111.11111111.11111100.00000000
```

Convert:

```text id="c21"
11111100
=
128+64+32+16+8+4
=
252
```

Final subnet mask:

```text id="c22"
255.255.252.0
```

---

# 10. The Increment Trick

Take subnet mask:

```text id="c23"
255.255.252.0
```

Interesting octet:

```text id="c24"
252
```

Calculate:

```text id="c25"
256 - 252 = 4
```

Networks increment by 4:

```text id="c26"
10.0.0.0
10.0.4.0
10.0.8.0
10.0.12.0
```

That’s how subnet ranges are found.

---

# 11. Fast Mental Rules

| CIDR | Approx Azure Hosts |
| ---- | ------------------ |
| /24  | 250                |
| /23  | 500                |
| /22  | 1000               |
| /21  | 2000               |

Each step LEFT doubles the size.

---

# 12. Azure Design Advice

Avoid tiny subnets in production.

Cloud services consume IPs quickly:

* AKS
* Private Endpoints
* Firewalls
* Bastion
* Scale Sets

Common recommendations:

| Service              | Recommended Minimum |
| -------------------- | ------------------- |
| General subnet       | /24                 |
| AKS                  | /23 or larger       |
| Azure FirewallSubnet | /26                 |
| BastionSubnet        | /26                 |
| GatewaySubnet        | /27                 |

---

# 13. One-Liners To Remember

> Bigger CIDR = Smaller Network

> Moving LEFT doubles the subnet size

> Subnet masks are just binary ON bits converted to decimal

> Nobody complains a subnet is too big. They constantly complain it’s too small.
