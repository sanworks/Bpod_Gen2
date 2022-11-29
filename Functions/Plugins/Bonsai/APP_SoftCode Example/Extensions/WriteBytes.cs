using Bonsai;
using System;
using System.ComponentModel;
using System.Collections.Generic;
using System.Linq;
using System.Reactive.Linq;
using System.IO.Ports;

[Combinator]
[Description("")]
[WorkflowElementCategory(ElementCategory.Combinator)]
public class WriteBytes
{
    public IObservable<byte[]> Process(IObservable<byte[]> source, IObservable<SerialPort> serialPort)
    {
        return serialPort.SelectMany(port => source.Do(buffer => port.Write(buffer, 0, buffer.Length)));
    }
}
