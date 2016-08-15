struct Version {
    bit<8> major;
    bit<8> minor;
}

error {
    NoError,
    PacketTooShort,
    NoMatch,
    EmptyStack,
    FullStack,
    OverwritingHeader,
    HeaderTooShort
}

extern packet_in {
    void extract<T>(out T hdr);
    void extract<T>(out T variableSizeHeader, in bit<32> variableFieldSizeInBits);
    T lookahead<T>();
    void advance(in bit<32> sizeInBits);
    bit<32> length();
}

extern packet_out {
    void emit<T>(in T hdr);
}

action NoAction() {
}
match_kind {
    exact,
    ternary,
    lpm
}

match_kind {
    range,
    selector
}

struct standard_metadata_t {
    bit<9>  ingress_port;
    bit<9>  egress_spec;
    bit<9>  egress_port;
    bit<32> clone_spec;
    bit<32> instance_type;
    bit<1>  drop;
    bit<16> recirculate_port;
    bit<32> packet_length;
}

extern Checksum16 {
    bit<16> get<D>(in D data);
}

enum CounterType {
    packets,
    bytes,
    packets_and_bytes
}

extern counter {
    counter(bit<32> size, CounterType type);
    void count(in bit<32> index);
}

extern direct_counter {
    direct_counter(CounterType type);
}

extern meter {
    meter(bit<32> size, CounterType type);
    void execute_meter<T>(in bit<32> index, out T result);
}

extern direct_meter<T> {
    direct_meter(CounterType type);
    void read(out T result);
}

extern register<T> {
    register(bit<32> size);
    void read(out T result, in bit<32> index);
    void write(in bit<32> index, in T value);
}

extern action_profile {
    action_profile(bit<32> size);
}

enum HashAlgorithm {
    crc32,
    crc32_custom,
    crc16,
    crc16_custom,
    random,
    identity
}

extern action_selector {
    action_selector(HashAlgorithm algorithm, bit<32> size, bit<32> outputWidth);
}

parser Parser<H, M>(packet_in b, out H parsedHdr, inout M meta, inout standard_metadata_t standard_metadata);
control VerifyChecksum<H, M>(in H hdr, inout M meta, inout standard_metadata_t standard_metadata);
control Ingress<H, M>(inout H hdr, inout M meta, inout standard_metadata_t standard_metadata);
control Egress<H, M>(inout H hdr, inout M meta, inout standard_metadata_t standard_metadata);
control ComputeCkecksum<H, M>(inout H hdr, inout M meta, inout standard_metadata_t standard_metadata);
control Deparser<H>(packet_out b, in H hdr);
package V1Switch<H, M>(Parser<H, M> p, VerifyChecksum<H, M> vr, Ingress<H, M> ig, Egress<H, M> eg, ComputeCkecksum<H, M> ck, Deparser<H> dep);
struct ingress_metadata_t {
    bit<3>  lkp_pkt_type;
    bit<48> lkp_mac_sa;
    bit<48> lkp_mac_da;
    bit<16> lkp_mac_type;
}

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header vlan_tag_t {
    bit<3>  pcp;
    bit<1>  cfi;
    bit<12> vid;
    bit<16> etherType;
}

struct metadata {
    @name("ingress_metadata") 
    ingress_metadata_t ingress_metadata;
}

struct headers {
    @name("ethernet") 
    ethernet_t    ethernet;
    @name("vlan_tag_") 
    vlan_tag_t[2] vlan_tag_;
}

parser ParserImpl(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name("parse_ethernet") state parse_ethernet {
        packet.extract<ethernet_t>(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            16w0x8100: parse_vlan;
            16w0x9100: parse_vlan;
            16w0x9200: parse_vlan;
            16w0x9300: parse_vlan;
            default: accept;
        }
    }
    @name("parse_vlan") state parse_vlan {
        packet.extract<vlan_tag_t>(hdr.vlan_tag_.next);
        transition select(hdr.vlan_tag_.last.etherType) {
            16w0x8100: parse_vlan;
            16w0x9100: parse_vlan;
            16w0x9200: parse_vlan;
            16w0x9300: parse_vlan;
            default: accept;
        }
    }
    @name("start") state start {
        transition parse_ethernet;
    }
}

control ingress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name("set_valid_outer_unicast_packet_untagged") action set_valid_outer_unicast_packet_untagged() {
        meta.ingress_metadata.lkp_pkt_type = 3w1;
        meta.ingress_metadata.lkp_mac_sa = hdr.ethernet.srcAddr;
        meta.ingress_metadata.lkp_mac_da = hdr.ethernet.dstAddr;
        meta.ingress_metadata.lkp_mac_type = hdr.ethernet.etherType;
    }
    @name("set_valid_outer_unicast_packet_single_tagged") action set_valid_outer_unicast_packet_single_tagged() {
        meta.ingress_metadata.lkp_pkt_type = 3w1;
        meta.ingress_metadata.lkp_mac_sa = hdr.ethernet.srcAddr;
        meta.ingress_metadata.lkp_mac_da = hdr.ethernet.dstAddr;
        meta.ingress_metadata.lkp_mac_type = hdr.vlan_tag_[0].etherType;
    }
    @name("set_valid_outer_unicast_packet_double_tagged") action set_valid_outer_unicast_packet_double_tagged() {
        meta.ingress_metadata.lkp_pkt_type = 3w1;
        meta.ingress_metadata.lkp_mac_sa = hdr.ethernet.srcAddr;
        meta.ingress_metadata.lkp_mac_da = hdr.ethernet.dstAddr;
        meta.ingress_metadata.lkp_mac_type = hdr.vlan_tag_[1].etherType;
    }
    @name("set_valid_outer_unicast_packet_qinq_tagged") action set_valid_outer_unicast_packet_qinq_tagged() {
        meta.ingress_metadata.lkp_pkt_type = 3w1;
        meta.ingress_metadata.lkp_mac_sa = hdr.ethernet.srcAddr;
        meta.ingress_metadata.lkp_mac_da = hdr.ethernet.dstAddr;
        meta.ingress_metadata.lkp_mac_type = hdr.ethernet.etherType;
    }
    @name("set_valid_outer_multicast_packet_untagged") action set_valid_outer_multicast_packet_untagged() {
        meta.ingress_metadata.lkp_pkt_type = 3w2;
        meta.ingress_metadata.lkp_mac_sa = hdr.ethernet.srcAddr;
        meta.ingress_metadata.lkp_mac_da = hdr.ethernet.dstAddr;
        meta.ingress_metadata.lkp_mac_type = hdr.ethernet.etherType;
    }
    @name("set_valid_outer_multicast_packet_single_tagged") action set_valid_outer_multicast_packet_single_tagged() {
        meta.ingress_metadata.lkp_pkt_type = 3w2;
        meta.ingress_metadata.lkp_mac_sa = hdr.ethernet.srcAddr;
        meta.ingress_metadata.lkp_mac_da = hdr.ethernet.dstAddr;
        meta.ingress_metadata.lkp_mac_type = hdr.vlan_tag_[0].etherType;
    }
    @name("set_valid_outer_multicast_packet_double_tagged") action set_valid_outer_multicast_packet_double_tagged() {
        meta.ingress_metadata.lkp_pkt_type = 3w2;
        meta.ingress_metadata.lkp_mac_sa = hdr.ethernet.srcAddr;
        meta.ingress_metadata.lkp_mac_da = hdr.ethernet.dstAddr;
        meta.ingress_metadata.lkp_mac_type = hdr.vlan_tag_[1].etherType;
    }
    @name("set_valid_outer_multicast_packet_qinq_tagged") action set_valid_outer_multicast_packet_qinq_tagged() {
        meta.ingress_metadata.lkp_pkt_type = 3w2;
        meta.ingress_metadata.lkp_mac_sa = hdr.ethernet.srcAddr;
        meta.ingress_metadata.lkp_mac_da = hdr.ethernet.dstAddr;
        meta.ingress_metadata.lkp_mac_type = hdr.ethernet.etherType;
    }
    @name("set_valid_outer_broadcast_packet_untagged") action set_valid_outer_broadcast_packet_untagged() {
        meta.ingress_metadata.lkp_pkt_type = 3w4;
        meta.ingress_metadata.lkp_mac_sa = hdr.ethernet.srcAddr;
        meta.ingress_metadata.lkp_mac_da = hdr.ethernet.dstAddr;
        meta.ingress_metadata.lkp_mac_type = hdr.ethernet.etherType;
    }
    @name("set_valid_outer_broadcast_packet_single_tagged") action set_valid_outer_broadcast_packet_single_tagged() {
        meta.ingress_metadata.lkp_pkt_type = 3w4;
        meta.ingress_metadata.lkp_mac_sa = hdr.ethernet.srcAddr;
        meta.ingress_metadata.lkp_mac_da = hdr.ethernet.dstAddr;
        meta.ingress_metadata.lkp_mac_type = hdr.vlan_tag_[0].etherType;
    }
    @name("set_valid_outer_broadcast_packet_double_tagged") action set_valid_outer_broadcast_packet_double_tagged() {
        meta.ingress_metadata.lkp_pkt_type = 3w4;
        meta.ingress_metadata.lkp_mac_sa = hdr.ethernet.srcAddr;
        meta.ingress_metadata.lkp_mac_da = hdr.ethernet.dstAddr;
        meta.ingress_metadata.lkp_mac_type = hdr.vlan_tag_[1].etherType;
    }
    @name("set_valid_outer_broadcast_packet_qinq_tagged") action set_valid_outer_broadcast_packet_qinq_tagged() {
        meta.ingress_metadata.lkp_pkt_type = 3w4;
        meta.ingress_metadata.lkp_mac_sa = hdr.ethernet.srcAddr;
        meta.ingress_metadata.lkp_mac_da = hdr.ethernet.dstAddr;
        meta.ingress_metadata.lkp_mac_type = hdr.ethernet.etherType;
    }
    @name("validate_outer_ethernet") table validate_outer_ethernet() {
        actions = {
            set_valid_outer_unicast_packet_untagged();
            set_valid_outer_unicast_packet_single_tagged();
            set_valid_outer_unicast_packet_double_tagged();
            set_valid_outer_unicast_packet_qinq_tagged();
            set_valid_outer_multicast_packet_untagged();
            set_valid_outer_multicast_packet_single_tagged();
            set_valid_outer_multicast_packet_double_tagged();
            set_valid_outer_multicast_packet_qinq_tagged();
            set_valid_outer_broadcast_packet_untagged();
            set_valid_outer_broadcast_packet_single_tagged();
            set_valid_outer_broadcast_packet_double_tagged();
            set_valid_outer_broadcast_packet_qinq_tagged();
            NoAction();
        }
        key = {
            hdr.ethernet.dstAddr      : ternary;
            hdr.vlan_tag_[0].isValid(): exact;
            hdr.vlan_tag_[1].isValid(): exact;
        }
        size = 64;
        default_action = NoAction();
    }
    apply {
        validate_outer_ethernet.apply();
    }
}

control egress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    apply {
    }
}

control DeparserImpl(packet_out packet, in headers hdr) {
    apply {
        packet.emit<ethernet_t>(hdr.ethernet);
        packet.emit<vlan_tag_t[2]>(hdr.vlan_tag_);
    }
}

control verifyChecksum(in headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    apply {
    }
}

control computeChecksum(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    apply {
    }
}

V1Switch<headers, metadata>(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;