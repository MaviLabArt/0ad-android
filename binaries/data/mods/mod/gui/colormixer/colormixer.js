/**
 * This page allows to mix color using sliders one for each of three channels in range of 0 to 255 with
 * step of 1, returning sanitized color when closing
 */

const labels = [translate("Red"), translate("Green"), translate("Blue")];
const captions = [translate("Cancel"), translate("Save")];

function resizeChanel(i)
{
	const object0 = Engine.GetGUIObjectByName("color[0]");
	const height0 = object0.size.bottom - object0.size.top;
	const object = Engine.GetGUIObjectByName("color[" + i + "]");

	object.size.top = i * height0;
	object.size.bottom = (i + 1) * height0;
}

function initializeButtons()
{
	const button = [];
	const prom = setButtonCaptionsAndVisibility(button, captions,
		Engine.GetGUIObjectByName("cancelHotkey"), "cmButton");
	distributeButtonsHorizontally(button, captions);
	return prom;
}

/**
 * @param {String} initialColor - initial color as RGB string e.g. 100 0 200
 */
export async function init(initialColor)
{
	Engine.GetGUIObjectByName("titleBar").caption = translate("Color");
	Engine.GetGUIObjectByName("infoLabel").caption =
		translate("Move the sliders to change the Red, Green and Blue components of the Color");

	const color = [0, 0, 0];
	const sliders = [];
	const valuesText = [];
	const closePromise = initializeButtons();

	const updateColorPreview = () => {
		const colorDisplay = Engine.GetGUIObjectByName("colorDisplay");
		colorDisplay.sprite = "color:" + color.join(" ");
	};

	const updateFromSlider = index => {
		color[index] = Math.floor(sliders[index].value);
		valuesText[index].caption = color[index];
		updateColorPreview();
	};

	const c = initialColor.split(" ");

	for (let i = 0; i < color.length; i++)
	{
		color[i] = Math.floor(+c[i] || 0);
		resizeChanel(i);

		sliders[i] = Engine.GetGUIObjectByName("colorSlider[" + i + "]");
		const slider = sliders[i];
		slider.min_value = 0;
		slider.max_value = 255;
		slider.value = color[i];
		slider.onValueChange = () => {updateFromSlider(i);};

		valuesText[i] = Engine.GetGUIObjectByName("colorValue[" + i + "]");
		valuesText[i].caption = color[i];

		Engine.GetGUIObjectByName("colorLabel[" + i + "]").caption = labels[i];
	}

	updateColorPreview();
	// Update return color on cancel to prevent malformed values from initial input.
	const sanitizedColor = color.join(" ");

	return await closePromise === 0 ? sanitizedColor : color.join(" ");
}
