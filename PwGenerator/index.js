const characters = ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z","a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9","~","`","!","@","#","$","%","^","&","*","(",")","_","-","+","=","{","[","}","]",",","|",":",";","<",">",".","?",
"/"]

let pwLength = 15
let alphabetIndex = 52
let includeSymbolsAndNumbers = true
let pw1El = document.getElementById("pw1-el")
let pw2El = document.getElementById("pw2-el")
let toggleEl = document.getElementById("toggle-el")
let pwLengthEl = document.getElementById("pw-length")

function generatePasswords() {
    pw1El.textContent = ""
    pw2El.textContent = ""

    let arrayIndex = characters.length
    if(includesSymbolsAndNumbers == false)
        arrayIndex = alphabetIndex
    
    for(let i = 0;i < pwLength; i++) {
        let randomIndex = Math.floor(Math.random() * arrayIndex)
        pw2El.textContent += characters[randomIndex]
    }
}

toggleEl.addEventListener("click", function() {
    includeSymbolsAndNumbers ? false : true
})

function changePwLength() {
    let newLength = pwLengthEl.value
    pwLength = parseInt(newLength, 10)
}

/*
function copyToClipboard() {}
*/

