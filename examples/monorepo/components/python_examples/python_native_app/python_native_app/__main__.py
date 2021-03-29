import time
import python_library

print("APP running")

while True:
    print("calling python_library.hello()")
    python_library.hello()

    time.sleep(2)
