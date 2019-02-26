namespace TestServer.Hubs
{
    public class ComplexInParameter
    {
        public string FirstName { get; set; }
        public string LastName { get; set; }

        public override string ToString()
        {
            return $"FirstName: {FirstName}, LastName_ {LastName}";
        }
    }

    public class ComplexReturnValue
    {
        public string GreetingText { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }

        public override string ToString()
        {
            return $"{nameof(GreetingText)}: {GreetingText}, {nameof(FirstName)}: {FirstName}, {nameof(LastName)}: {LastName}";
        }
    }
}