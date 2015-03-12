Text can normally only be drawn left-aligned, right-aligned or centered. This unit provides a method to draw fully justified text - that is, text that meets both the left- and right-hand edges of the bounding rectangle, with variable spacing between words.

It wraps the Windows API SetTextJustification, but includes an automatically used alternative implementation for fonts that cannot be used with that API. This includes Segoe UI.

Project home page: http://parnassus.co/open-source/justified-text/