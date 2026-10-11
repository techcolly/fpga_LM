"""Interactive prompt loop that runs every next-token prediction on the FPGA over UART.

Same text handling as chat.py (spelling correction, phrase normalizing, vocabulary);
only the prediction step differs. For each generated word it sends 4 raw bytes (the
last 4 token ids, each 0-63) and reads 1 raw byte back (the predicted token id).

Run from the repo root:
    python -m langModel.chat_fpga --list                 show the serial ports
    python -m langModel.chat_fpga --port COM5            talk to the board
    python -m langModel.chat_fpga --port COM5 --verify   also check every reply
                                                         against the integer reference

Needs pyserial (pip install pyserial); --verify needs nothing else, it reads the
checkpoint itself without PyTorch.
"""

import argparse
import sys
from pathlib import Path

# Lets this file run directly as well as via -m.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from langModel.chat import reply
from langModel.export_mem import DEFAULT_CHECKPOINT, load_state_dict, quantize_state_dict
from langModel.int_infer import int_forward
from langModel.tokenizer import CONTEXT_SIZE
from langModel.vocab import BOS_ID, EOS_ID, PAD_ID

BAUD = 115200
REPLY_TIMEOUT_SECONDS = 1.0
MAX_TOKEN_ID = 63


class FpgaLink:
    # port: an open serial port (anything with write, read, flush, reset_input_buffer).
    def __init__(self, port):
        self.port = port

    # Sends one 4-token request and returns the predicted token id.
    def predict(self, context):
        assert len(context) == CONTEXT_SIZE and all(0 <= t <= MAX_TOKEN_ID for t in context)
        self.port.reset_input_buffer()
        self.port.write(bytes(context))
        self.port.flush()
        return self._read_reply()

    def _read_reply(self):
        data = self.port.read(1)
        if len(data) == 0:
            raise TimeoutError(f"no reply from the FPGA within {REPLY_TIMEOUT_SECONDS} s")
        if data[0] > MAX_TOKEN_ID:
            raise ValueError(f"FPGA replied {data[0]}, which is not a token id (0-{MAX_TOKEN_ID})")
        return data[0]

    # The board counts bytes in groups of 4. If an earlier session left it part way through
    # a group, sending single zero bytes until it answers lines the count up again.
    def resync(self):
        for _ in range(CONTEXT_SIZE):
            self.port.reset_input_buffer()
            self.port.write(bytes([0]))
            self.port.flush()
            if len(self.port.read(1)) == 1:
                break
        else:
            raise TimeoutError("the FPGA did not answer while resynchronizing; check the port and the bitstream")
        self.port.reset_input_buffer()


# Returns a generate(params, prompt_ids, max_len) with the same shape as int_infer.generate_int,
# but every prediction runs on the FPGA. With verify_params set, each reply is also compared
# with int_forward, and a mismatch is printed.
def make_fpga_generator(link, verify_params=None, stats=None):
    def generate(params, prompt_ids=(), max_len=12):
        ids = [PAD_ID] * (CONTEXT_SIZE - 1) + [BOS_ID] + list(prompt_ids)
        generated = []
        for _ in range(max_len):
            context = ids[-CONTEXT_SIZE:]
            next_id = link.predict(context)
            if stats is not None:
                stats["predictions"] += 1
            if verify_params is not None:
                _, expected_id = int_forward(context, verify_params)
                if next_id != expected_id:
                    print(f"  (MISMATCH for context {context}: FPGA {next_id}, reference {expected_id})")
                    if stats is not None:
                        stats["mismatches"] += 1
            if next_id == EOS_ID:
                break
            ids.append(next_id)
            generated.append(next_id)
        return generated

    return generate


def main():
    parser = argparse.ArgumentParser(description="Chat with the tiny language model running on the FPGA.")
    parser.add_argument("--port", help="serial port of the Arty board, for example COM5")
    parser.add_argument("--baud", type=int, default=BAUD)
    parser.add_argument("--verify", action="store_true", help="check every FPGA reply against the integer reference")
    parser.add_argument("--checkpoint", type=Path, default=DEFAULT_CHECKPOINT)
    parser.add_argument("--list", action="store_true", help="list the serial ports and exit")
    args = parser.parse_args()

    try:
        import serial
        import serial.tools.list_ports
    except ModuleNotFoundError:
        sys.exit("pyserial is not installed: run  pip install pyserial")

    if args.list:
        for info in serial.tools.list_ports.comports():
            print(f"{info.device}  {info.description}")
        return
    if not args.port:
        sys.exit("give the board's serial port with --port COM5 (see --list)")

    verify_params = quantize_state_dict(load_state_dict(args.checkpoint)) if args.verify else None
    stats = {"predictions": 0, "mismatches": 0}

    with serial.Serial(args.port, baudrate=args.baud, bytesize=8, parity="N", stopbits=1,
                       timeout=REPLY_TIMEOUT_SECONDS) as port:
        link = FpgaLink(port)
        link.resync()
        generate = make_fpga_generator(link, verify_params, stats)
        print(f"connected to {args.port} at {args.baud} baud" + ("; verifying every reply" if args.verify else ""))

        while True:
            try:
                text = input("you> ").strip()
            except EOFError:
                break
            if text.lower() in ("quit", "exit"):
                break
            if not text:
                continue
            try:
                answer, notes = reply(verify_params, text, generate)
            except (TimeoutError, ValueError) as problem:
                print(f"  (FPGA problem: {problem}; resynchronizing)")
                link.resync()
                continue
            for note in notes:
                print(f"  ({note})")
            print("model>", answer if answer else "(no reply)")
            if args.verify:
                print(f"  ({stats['predictions']} FPGA predictions so far, {stats['mismatches']} mismatches)")


if __name__ == "__main__":
    main()
