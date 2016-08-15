#include "/home/cdodd/p4c/p4include/core.p4"
#include "/home/cdodd/p4c/p4include/v1model.p4"

header data_t {
    bit<32> f1;
    bit<32> f2;
    bit<8>  b1;
    bit<8>  b2;
    bit<8>  b3;
    bit<8>  b4;
}

header data2_t {
    bit<8> x1;
    bit<8> x2;
}

struct metadata {
}

struct headers {
    @name("data") 
    data_t  data;
    @name("data2") 
    data2_t data2;
}

parser ParserImpl(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name("parse_data2") state parse_data2 {
        packet.extract(hdr.data2);
        transition accept;
    }
    @name("start") state start {
        packet.extract(hdr.data);
        transition select(hdr.data.b1) {
            8w0x1: parse_data2;
            default: accept;
        }
    }
}

control ingress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name("setb1") action setb1(bit<8> val, bit<9> port) {
        hdr.data.b1 = val;
        standard_metadata.egress_spec = port;
    }
    @name("noop") action noop() {
    }
    @name("test1") table test1() {
        actions = {
            setb1;
            noop;
            NoAction;
        }
        key = {
            hdr.data.f1: exact;
        }
        default_action = NoAction();
    }
    @name("test2") table test2() {
        actions = {
            setb1;
            noop;
            NoAction;
        }
        key = {
            hdr.data.f2: exact;
        }
        default_action = NoAction();
    }
    apply {
        if (hdr.data2.isValid()) {
            test1.apply();
        }
        test2.apply();
    }
}

control egress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    apply {
    }
}

control DeparserImpl(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.data);
        packet.emit(hdr.data2);
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

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;