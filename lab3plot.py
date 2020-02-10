import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import sys, time, math

import serial
import serial.tools.list_ports

xsize=100

try:
    ser.close() # try to close the last opened port
except:
    print('')

portlist=list(serial.tools.list_ports.comports())
print ('Available serial ports (will try to open the last one):')
for item in portlist:
    print (item[0])

# configure the serial port
ser = serial.Serial(
    port=item[0],
    baudrate=115200,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_TWO,
    bytesize=serial.EIGHTBITS
)
ser.isOpen()

print ('To stop press Ctrl+C')

def data_gen():
    t = data_gen.t
    
    while True:
       strin = ser.readline()
       t+=1
       val= float(strin.decode())
       print(float(strin.decode()))
       yield t, val
    

def run(data):
    # update the data
    t,y = data
    if t>-1:
        xdata.append(t)
        ydata.append(y)
        if t>xsize: # Scroll to the left.
            ax.set_xlim(t-xsize, t)
        line.set_data(xdata, ydata)

    return line

def on_close_figure(event):
    sys.exit(0)

data_gen.t = -1
fig = plt.figure()
fig.canvas.mpl_connect('close_event', on_close_figure)
ax = fig.add_subplot(111)
line, = ax.plot([], [], lw=2, label='Temperature curve')
ax.set_ylim(-10, 70)
ax.set_xlim(0, xsize)
ax.grid()
ax.legend()
plt.title('LM335 Temperature Plot')
plt.xlabel('Time (Seconds)')
plt.ylabel('Temperature (Celsius)')

xdata, ydata = [], []

# Important: Although blit=True makes graphing faster, we need blit=False to prevent
# spurious lines to appear when resizing the stripchart.
ani = animation.FuncAnimation(fig, run, data_gen, blit=False, interval=1000, repeat=False)
plt.show()

