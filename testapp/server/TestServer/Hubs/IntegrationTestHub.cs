using System;
using System.Threading.Channels;
using System.Threading.Tasks;
using Microsoft.AspNetCore.SignalR;

namespace TestServer.Hubs
{
  public class IntegrationTestHub : Hub
  {

    #region Consts, Fields, Properties, Events

    #endregion

    #region Methods

    #region Client invokes a server method.

    /// <summary>
    /// No parameters
    /// No returns
    /// </summary>
    /// <returns></returns>
    public void MethodNoParametersNoReturnValue()
    {
      Console.WriteLine("'MethodNoParametersNoReturnValue' invoked.");
    }

    /// <summary>
    /// No parameters
    /// Simple parameter return
    /// </summary>
    public string MethodNoParametersSimpleReturnValue()
    {
      Console.WriteLine("'MethodNoParametersSimpleReturnValue' invoked.");
      return "MethodNoParametersSimpleReturnValue";
    }

    /// <summary>
    /// One simple parameter
    /// No Returns
    /// </summary>
    public void MethodOneSimpleParameterNoReturnValue(string p1)
    {
      Console.WriteLine($"'MethodOneSimpleParameterNoReturnValue' invoked. Parameter value: '{p1}");
    }

    /// <summary>
    /// One simple parameters
    /// Simple parameter return
    /// </summary>
    public string MethodOneSimpleParameterSimpleReturnValue(string p1)
    {
      Console.WriteLine($"'MethodOneSimpleParameterSimpleReturnValue' invoked. Parameter value: '{p1}");
      return p1;
    }

    public ComplexReturnValue MethodWithComplexParameterAndComplexReturnValue(ComplexInParameter req)
    {
      
      Console.WriteLine($"'MethodWithComplexParameterAndReturnValue' invoked. Parameter value: '{req}");
      return new ComplexReturnValue
      {
        FirstName = req.FirstName,
        LastName = req.LastName,
        GreetingText = $"Hello {req.FirstName} {req.LastName}"
      };
    }

    #endregion

    #region Server invokes a client method

    /// <summary>
    /// No parameters
    /// No returns
    /// </summary>
    /// <returns></returns>
    public async Task ServerInvokeMethodNoParametersNoReturnValue()
    {
      Console.WriteLine("'ServerInvokeMethodNoParametersNoReturnValue' invoked.");
      await Clients.Caller.SendAsync("ServerInvokeMethodNoParametersNoReturnValue", null);
    }

    /// <summary>
    /// No parameters
    /// Simple parameter return
    /// </summary>
    public async Task ServerInvokeMethodSimpleParametersNoReturnValue()
    {
      Console.WriteLine("'ServerInvokeMethodSimpleParametersNoReturnValue' invoked.");
      await Clients.Caller.SendCoreAsync("ServerInvokeMethodSimpleParametersNoReturnValue", new object[]{ "p1", 1 });
    }

    #endregion

    #region Stream To Client

    public ChannelReader<int> StreamCounterValuesToClient(int count, int delayInMs)
    {
      var channel = Channel.CreateUnbounded<int>();

      // We don't want to await WriteItems, otherwise we'd end up waiting 
      // for all the items to be written before returning the channel back to
      // the client.
      _ = sendItemsClient(channel.Writer, count, delayInMs);

      return channel.Reader;
    }

    private async Task sendItemsClient(ChannelWriter<int> writer, int count, int delayInMs)
    {
      for (var i = 0; i < count; i++)
      {
        await Task.Delay(delayInMs);
        var now = DateTime.Now;
        Console.WriteLine($"{now:HH:mm:ss.fff}: Send value '{i}' to client.");
        await writer.WriteAsync(i);
      }

      writer.TryComplete();
    }

    #endregion

    #endregion
  }
}