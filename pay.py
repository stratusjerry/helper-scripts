import sys

YearWorkingDays = 260  # Working Day in a Year
PTO = 30  # Includes holidays

ActualWorkingDays = YearWorkingDays - PTO
ActualWorkingHours = ActualWorkingDays * 8


def formatcurrency(takein):
    formatted_float = "${:,.2f}".format(takein)
    return formatted_float


base = sys.argv[1]
print(f'base is {base}')
HrlyPay = base / ActualWorkingHours
#print(f'Hourly Pay is ${str(round(HrlyPay, 2))}')
print(f'Hourly Pay is {formatcurrency(HrlyPay)}')
PTOvalue = PTO * 8 * HrlyPay
print(f'Value of PTO is {formatcurrency(PTOvalue)}')
#print(f'Total Hours Worked Pay is {formatcurrency(ActualWorkingHours * HrlyPay)}')
print(f'Total Hourly Compensation is {formatcurrency(PTOvalue + base)}')
