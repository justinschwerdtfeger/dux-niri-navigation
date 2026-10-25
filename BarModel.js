.pragma library
// The host's primary extent already excludes frame margins. Only occupied
// neighboring sections and the effective pill padding reduce the budget.
function primaryBudget({
    length,
    section,
    leading,
    centerStart,
    center,
    trailing,
    siblings,
    gap,
    padding,
}) {
    let available = length;
    if (section === 'left') {
        if (trailing > 0) available = Math.min(available, length - trailing - gap);
        if (center > 0) available = Math.min(available, centerStart - gap);
    } else if (section === 'right') {
        if (leading > 0) available = Math.min(available, length - leading - gap);
        if (center > 0) available = Math.min(available, length - centerStart - center - gap);
    } else {
        available =
            2 *
            Math.max(
                0,
                Math.min(
                    length / 2 - (leading > 0 ? leading + gap : 0),
                    length / 2 - (trailing > 0 ? trailing + gap : 0),
                ),
            );
    }
    const occupied = siblings.reduce((sum, size) => sum + size, 0);
    return Math.max(0, Math.floor(available - occupied - siblings.length * gap - padding * 2));
}
