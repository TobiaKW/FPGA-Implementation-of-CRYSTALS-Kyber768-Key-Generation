# PYNQ demo script: run keygen and print FULL SK + PK
  # read the keys from the board base on the topserver_axi register address
  #
  # Register map:
  # 0x00 CONTROL   [0]=start_pulse(W1P), [1]=clear_done(W1C)
  # 0x04 STATUS    [0]=done_sticky, [1]=rd_valid
  # 0x08 READ_CFG  [0]=rd_en, [1]=rd_sk (1=SK, 0=PK)
  # 0x0C READ_ADDR [11:0]
  # 0x10 READ_DATA [11:0]
  
  from pynq import Overlay, MMIO
  import time
  
  BIT_PATH = "/home/xilinx/design_1.bit"   # change according to the path of the .bit
  MMIO_BASE = 0x40000000                   # axi base address (check in BD Design)
  MMIO_RANGE = 0x1000
  
  SK_BYTES = 2400
  PK_BYTES = 1184
  
  REG_CONTROL   = 0x00
  REG_STATUS    = 0x04
  REG_READ_CFG  = 0x08
  REG_READ_ADDR = 0x0C
  REG_READ_DATA = 0x10
  
  def load_overlay():
      ol = Overlay(BIT_PATH)
      # some PYNQ versions auto-download in constructor, but explicit is fine
      ol.download()
      return ol
  
  
  def wait_done(mmio, timeout_s=5.0):
      t0 = time.time()
      while True:
          st = mmio.read(REG_STATUS)
          if st & 0x1:
              return
          if (time.time() - t0) > timeout_s:
              raise TimeoutError("Timeout waiting for done_sticky")
          time.sleep(0.001)
  
  
  def wait_rd_valid(mmio, timeout_s=0.05):
      t0 = time.time()
      while True:
          st = mmio.read(REG_STATUS)
          if st & 0x2:
              return
          if (time.time() - t0) > timeout_s:
              raise TimeoutError("Timeout waiting for rd_valid")
  
  
  def read_byte(mmio, addr, is_sk):
      mmio.write(REG_READ_ADDR, addr & 0xFFF)
      mmio.write(REG_READ_CFG, (1 << 0) | ((1 if is_sk else 0) << 1))  # rd_en + rd_sk
      wait_rd_valid(mmio)
      val = mmio.read(REG_READ_DATA) & 0xFF
      mmio.write(REG_READ_CFG, 0x0)  # deassert rd_en
      return val
  
  
  def read_blob(mmio, nbytes, is_sk):
      return bytes(read_byte(mmio, i, is_sk) for i in range(nbytes))
  
  
  def pretty_hex_dump(label, data, width=32):
      print(f"{label} ({len(data)} bytes):")
      hx = data.hex()
      for i in range(0, len(hx), width * 2):
          print(hx[i:i + width * 2])
  
  
  def main():
      print("Loading overlay...")
      load_overlay()
      mmio = MMIO(MMIO_BASE, MMIO_RANGE)
  
      # clear done, start keygen pulse
      mmio.write(REG_CONTROL, 0x2)  # clear_done
      mmio.write(REG_CONTROL, 0x1)  # start_pulse
  
      print("Waiting for keygen done...")
      wait_done(mmio, timeout_s=10.0)
      print("Keygen finished.")
  
      print("Reading SK...")
      sk = read_blob(mmio, SK_BYTES, is_sk=True)
  
      print("Reading PK...")
      pk = read_blob(mmio, PK_BYTES, is_sk=False)
  
      # debug reads (optional)
      print(f"nz(SK) = {sum(1 for b in sk if b != 0)} / {len(sk)}")
      print(f"nz(PK) = {sum(1 for b in pk if b != 0)} / {len(pk)}")
  
      # Print full keys (hex dump)
      pretty_hex_dump("SK", sk, width=32)
      pretty_hex_dump("PK", pk, width=32)
  
  
  if __name__ == "__main__":
    main()