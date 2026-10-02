using CampusEvents.Backend;
using Moq;
using Xunit;

namespace RegistrationValidator.Tests;

public class RegistrationValidatorTests
{
    private readonly Mock<IEventRepository> _repo = new();
    private CampusEvents.Backend.RegistrationValidator Sut() => new(_repo.Object);

    [Theory]
    [InlineData("ana.reyes@univ.edu.ph")]
    [InlineData("  ANA@UNIV.EDU.PH  ")]
    public void IsValidStudentEmail_AcceptsSchoolDomain(string email)
        => Assert.True(Sut().IsValidStudentEmail(email));

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("ana@gmail.com")]
    [InlineData("ana@univ.edu.ph.evil.com")]   // spoofed suffix
    [InlineData("@univ.edu.ph")]               // missing local part
    public void IsValidStudentEmail_RejectsBadInput(string? email)
        => Assert.False(Sut().IsValidStudentEmail(email));

    [Fact]
    public void Validate_InvalidEmail_NeverTouchesRepository()
    {
        var result = Sut().Validate("bad@gmail.com", 1);

        Assert.False(result.IsValid);
        _repo.Verify(r => r.GetSeatInfo(It.IsAny<int>()), Times.Never);
    }

    [Fact]
    public void Validate_UnknownEvent_Fails()
    {
        _repo.Setup(r => r.GetSeatInfo(99)).Returns((EventSeatInfo?)null);

        var result = Sut().Validate("ana@univ.edu.ph", 99);

        Assert.False(result.IsValid);
        Assert.Equal("Event not found.", result.Error);
    }

    [Fact]
    public void Validate_FullEvent_Fails()
    {
        _repo.Setup(r => r.GetSeatInfo(1)).Returns(new EventSeatInfo(1, 10, 10));

        var result = Sut().Validate("ana@univ.edu.ph", 1);

        Assert.False(result.IsValid);
        Assert.Equal("Event is fully booked.", result.Error);
    }

    [Fact]
    public void Validate_DuplicateRegistration_Fails()
    {
        _repo.Setup(r => r.GetSeatInfo(1)).Returns(new EventSeatInfo(1, 10, 3));
        _repo.Setup(r => r.IsAlreadyRegistered("ana@univ.edu.ph", 1)).Returns(true);

        var result = Sut().Validate("ana@univ.edu.ph", 1);

        Assert.False(result.IsValid);
    }

    [Fact]
    public void Validate_SeatAvailable_Succeeds()
    {
        _repo.Setup(r => r.GetSeatInfo(1)).Returns(new EventSeatInfo(1, 10, 9));
        _repo.Setup(r => r.IsAlreadyRegistered(It.IsAny<string>(), 1)).Returns(false);

        var result = Sut().Validate("ana@univ.edu.ph", 1);

        Assert.True(result.IsValid);
        Assert.Null(result.Error);
    }
}
