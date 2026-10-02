using System.Text.RegularExpressions;

namespace CampusEvents.Backend;

public record EventSeatInfo(int EventId, int Capacity, int SeatsTaken);

/// <summary>External dependency (database) hidden behind an interface so tests can mock it.</summary>
public interface IEventRepository
{
    EventSeatInfo? GetSeatInfo(int eventId);
    bool IsAlreadyRegistered(string email, int eventId);
}

public record ValidationResult(bool IsValid, string? Error = null);

public class RegistrationValidator
{
    private static readonly Regex StudentEmail =
        new(@"^[A-Za-z0-9._%+-]+@univ\.edu\.ph$", RegexOptions.IgnoreCase | RegexOptions.Compiled);

    private readonly IEventRepository _events;
    public RegistrationValidator(IEventRepository events) => _events = events;

    public bool IsValidStudentEmail(string? email) =>
        !string.IsNullOrWhiteSpace(email) && StudentEmail.IsMatch(email.Trim());

    public ValidationResult Validate(string? email, int eventId)
    {
        if (!IsValidStudentEmail(email))
            return new(false, "Email must end with @univ.edu.ph.");

        var seats = _events.GetSeatInfo(eventId);
        if (seats is null)
            return new(false, "Event not found.");
        if (seats.SeatsTaken >= seats.Capacity)
            return new(false, "Event is fully booked.");
        if (_events.IsAlreadyRegistered(email!.Trim(), eventId))
            return new(false, "Already registered for this event.");

        return new(true);
    }
}
