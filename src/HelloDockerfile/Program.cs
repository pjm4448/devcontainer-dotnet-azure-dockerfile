var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () =>
{
    // HELLO_GREETING is baked into the image by .devcontainer/Dockerfile.
    var message = Environment.GetEnvironmentVariable("HELLO_GREETING")
        ?? "HELLO_GREETING is not set. Are you running inside the dev container?";
    return Results.Ok(new { message });
});

app.Run();
