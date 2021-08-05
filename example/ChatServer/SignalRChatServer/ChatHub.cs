using Microsoft.AspNetCore.SignalR;

namespace SignalRChatServer
{
  public class ChatHub : Hub
  {

    #region Consts, Fields, Properties, Events

    #endregion

    #region Methods

    public void Send(string name, string message)
    {
      // Call the "OnMessage" method to update clients.
      Clients.All.SendAsync("OnMessage", name, message);
    }

    #endregion
  }
}