using Microsoft.Data.SqlClient;
using System.Data;

namespace CampusEvents.Backend;

public class RegistrationService
{
    private readonly string _connectionString;

    // FIX 1: no hard-coded credentials. Inject from configuration / user-secrets / env variables.
    public RegistrationService(string connectionString)
    {
        _connectionString = connectionString ?? throw new ArgumentNullException(nameof(connectionString));
    }

    /// <summary>Returns the registration id for an email, or null if none exists.</summary>
    public string? GetUserRegistration(string inputEmail)
    {
        if (string.IsNullOrWhiteSpace(inputEmail))
            throw new ArgumentException("Email is required.", nameof(inputEmail));

        // FIX 2: 'using' guarantees Close()/Dispose() even if an exception is thrown (no connection leak).
        using var conn = new SqlConnection(_connectionString);
        using var cmd = new SqlCommand(
            @"SELECT TOP (1) r.RegistrationId
              FROM dbo.Registrations r
              INNER JOIN dbo.Users u ON u.UserId = r.UserId
              WHERE u.Email = @Email", conn);

        // FIX 3: parameterized query -> input is always data, never SQL (stops SQL injection).
        cmd.Parameters.Add("@Email", SqlDbType.NVarChar, 255).Value = inputEmail.Trim();

        conn.Open();

        // FIX 4: ExecuteScalar() returns null when no row matches; the original .ToString() would throw.
        object? result = cmd.ExecuteScalar();
        return result?.ToString();
    }
}
